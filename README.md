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

### Переключение только на неотстающий слейв

Согласно документации оркестратор выбирает максимально свежий и подходящий слейв в качестве кандидата в мастеры.

Можно использовать опцию `DelayMasterPromotionIfSQLThreadNotUpToDate`:

> if all replicas were lagging at time of failure, even the most up-to-date, promoted replica may yet have unapplied relay logs. When true, 'orchestrator' will wait for the SQL thread to catch up before promoting a new master. FailMasterPromotionIfSQLThreadNotUpToDate and DelayMasterPromotionIfSQLThreadNotUpToDate are mutually exclusive.

### Указать оркестратору какие реплики приоритетны для использования в качестве мастера, а какие нет

Смотри [документацию](https://github.com/github/orchestrator/blob/master/docs/topology-recovery.md#adding-promotion-rules)

Необходимо использовать Bash скрипт в cron для периодического обновления этих рекомендаций, поскольку их TTL равен 1 часу.

### Долго выполняется шаг Regrouping replicas via GTID

Смотри [issue](https://github.com/github/orchestrator/issues/648)