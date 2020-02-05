# Тестовое окружение для [MySQL Orchestrator](https://github.com/github/orchestrator)

Основная цель: иметь локальный тестовый стенд для проведения экспериментов по отказоустойчивости кластера MySQL.

Для удобства развертывания будем использовать Docker и Docker Compose.
Как результат ожидаю получить следующую конфигурацию стенда:

  1. Кластер MySQL (1 master, 3 slave). Версия MySQL - 5.7
  2. Один экземпляр MySQL Orchestrator, который будет отвечать за мониторинг кластера и выполнять автоматическое переключение мастера на одну из реплик, если основной мастер выходит из строя.
  3. Экземпляр HAProxy, через который клиент будет выполнять свои запросы.
  4. Простой клиент (Bash скрипт или Go приложение) для имитации нагрузки на БД.

В каждую ноду кластера добавлен SSH ключ для подключения из машины с оркестратором.

## MySQL Orchestrator

```bash
# Clone Git repository
cd <work-dir>
git clone https://github.com/github/orchestrator.git orchestrator/source

# Build Docker image
cd orchestrator/source
docker build -t orchestrator:latest .
```

### Исследовать топологию кластера

Можно выполнить через [UI](http://localhost:3000) или командную строку:

```bash
# docker-compose exec orchestrator ./orchestrator -c discover -i 172.20.0.200:3306
make discover
```

Вывести текущую топологию:

```bash
docker-compose exec orchestrator ./orchestrator -c topology -i 172.20.0.200:3306 cli
```

## VIP (виртуальные IP)

Используем следующие IP:
- 172.20.0.200 - мастер
- 172.20.0.201 - слейв 1
- 172.20.0.202 - слейв 2
- 172.20.0.203 - слейв 3

Основные команды:

```bash
# Добавить новый интерфейс и VIP
ifconfig eth0:0 172.20.0.200 up
arping -s 172.20.0.200 -c 3 172.20.0.1

# Выключить интерфейс
ifconfig eth0:0 down
```

## HAProxy

Страница администратора доступна по адресу [http://localhost:8080](http://localhost:8080)

## Алгоритм тестирования

Сборка и запуск песочницы:

```bash
make clean
make up
```

Инициализация кластера и оркестратора:

```bash
make load_schema
make discover
```

Через несколько секунд оркестратор построит топологию кластера и можно блокировать мастер:

```bash
# Эмулируем нагрузку в отдельном терминале
make try_sql n=200
# Можно заблокировать мастер через iptables
make node_drop n=node1
# Или полностью выключить ноду
docker-compose stop node1
```

Ожидаемое поведение: после блокировки мастера HAProxy должен отдавать ошибки, оркестратор должен перестроить кластер и сделать одну из реплик мастером, новый мастер получает VIP 172.20.0.200 и HAProxy возвращает ноду для записи в нагрузку, SQL запросы начинают успешно выполняться как на запись так и на чтение.

## FAQ

### Как используется cluster_domain из мета информации?

Используется в качестве дополнительной информации о кластере. Напрямую на работу оркестратора никак не влияет. 

Может использоваться в хуках: 

 - Шаблон подстановки `{failureClusterDomain}`,
 - Переменная окружения `ORC_FAILURE_CLUSTER_DOMAIN` ([topology_recovery.go#L314](https://github.com/github/orchestrator/blob/548265494b3107ca2581d6ccee059e062a759b77/go/logic/topology_recovery.go#L314)).

### Переключение только на неотстающий слейв

Согласно документации оркестратор выбирает максимально свежий и подходящий слейв в качестве кандидата в мастеры.

Можно использовать опцию `DelayMasterPromotionIfSQLThreadNotUpToDate`:

> if all replicas were lagging at time of failure, even the most up-to-date, promoted replica may yet have unapplied relay logs. When true, 'orchestrator' will wait for the SQL thread to catch up before promoting a new master. FailMasterPromotionIfSQLThreadNotUpToDate and DelayMasterPromotionIfSQLThreadNotUpToDate are mutually exclusive.

### Указать оркестратору какие реплики приоритетны для использования в качестве мастера, а какие нет

Смотри [документацию](https://github.com/github/orchestrator/blob/master/docs/topology-recovery.md#adding-promotion-rules)

Необходимо использовать Bash скрипт в cron для периодического обновления этих рекомендаций, поскольку их TTL равен 1 часу.

### Долго выполняется шаг Regrouping replicas via GTID

Смотри [issue](https://github.com/github/orchestrator/issues/648)

### Как вернуть старый мастер в новый кластер?

Рекомендуется в конфигурации MySQL `my.cnf` указать значение `read_only=1`. В случае перезагрузки ноды старый мастер будет автоматически подниматься в режиме ReadOnly.  

В процессе восстановления оркестратор автоматически устанавливает параметр `read_only` в 0 для нового мастера ([topology_recovery.go#L888](https://github.com/github/orchestrator/blob/548265494b3107ca2581d6ccee059e062a759b77/go/logic/topology_recovery.go#L888)), далее происходит попытка установить `read_only` в 1 на старом мастере в отдельной горутине ([topology_recovery.go#L893](https://github.com/github/orchestrator/blob/548265494b3107ca2581d6ccee059e062a759b77/go/logic/topology_recovery.go#L893)).

На старом мастере:

```sql
SET GLOBAL READ_ONLY=1;
CHANGE MASTER TO MASTER_HOST='172.20.0.200', MASTER_PORT=3306, MASTER_USER='repl', MASTER_PASSWORD='repl', MASTER_AUTO_POSITION=1;
CHANGE MASTER TO MASTER_CONNECT_RETRY=1, MASTER_RETRY_COUNT=86400;
START SLAVE;
```

Обновить оркестратор:

```bash
# -i - это старый мастер, -d - куда переносим (новый мастер)
docker-compose exec orchestrator ./orchestrator -c relocate -i 172.20.0.11 -d 172.20.0.12
```

### Время обнаружения проблемы и восстановления кластера

Какие [параметры MySQL](https://github.com/github/orchestrator/blob/master/docs/configuration-failure-detection.md#mysql-configuration) влияют на эти процессы:

 - `slave_net_timeout` - этот параметр определяет heartbeat интервал между репликой и мастером. Чем меньше значение, тем быстрее реплика сможет определить, что топология нарушена. Рекомендуемое значение - 4 секунды, heartbeat сигнал по умолчанию отправляется каждые `slave_net_timeout / 2` секунд.  
 - `CHANGE MASTER TO MASTER_CONNECT_RETRY=1, MASTER_RETRY_COUNT=86400`. В случае потери репликации параметр `MASTER_CONNECT_RETRY` определяет время в секундах, через которое реплика выполнит переподключение к мастеру (по умолчанию, 60 секунд). В случае сетевых проблем низкое значение этого параметра позволит быстро выполнить переподключение и предотвратить запуск процесса восстановления топологии.

[Подробнее](https://www.percona.com/blog/2011/12/29/actively-monitoring-replication-connectivity-with-mysqls-heartbeat/) про `MASTER_HEARTBEAT_PERIOD`. Как проверить текущее значение:

```
mysql_slave > SELECT HEARTBEAT_INTERVAL FROM performance_schema.replication_connection_configuration;
```

Также нужно помнить, что ([документация](https://dev.mysql.com/doc/refman/5.7/en/change-master-to.html)):

> Note that a change to the value or default setting of slave_net_timeout does not automatically change the heartbeat interval, whether that has been set explicitly or is using a previously calculated default. ... If slave_net_timeout is changed, you must also issue CHANGE MASTER TO to adjust the heartbeat interval to an appropriate value so that the heartbeat signal occurs before the connection timeout.

Параметры оркестратора:

 - `DelayMasterPromotionIfSQLThreadNotUpToDate`. Если равен `true`, то роль мастера не будет применена на реплике-кандидате до тех пор, пока SQL поток реплики не выполнит все непримененные транзакции из Relay Log.
 - `InstancePollSeconds`. Как часто выполняется построение/обновление топологии.
 - `RecoveryPollSeconds`. Как часто выполняется анализ топологии и в случае обнаружения проблемы запускается процедура восстановления топологии. Это [константа](https://github.com/github/orchestrator/blob/548265494b3107ca2581d6ccee059e062a759b77/go/config/config.go#L45), равная 1 секунде.

Каждый узел кластера опрашивается оркестратором один раз в `InstancePollSeconds` секунд. В случае обнаружения проблемы выполняется принудительное [обновление](https://github.com/github/orchestrator/blob/548265494b3107ca2581d6ccee059e062a759b77/go/logic/topology_recovery.go#L1409) состояния кластера и на основе этого принимается окончательное решение о выполнении процедуры восстановления.