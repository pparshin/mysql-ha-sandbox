# Тестовое окружение для [MySQL Orchestrator](https://github.com/github/orchestrator)

Основная цель: иметь локальный тестовый стенд для проведения экспериментов по отказоустойчивости кластера MySQL.

Для удобства развертывания будем использовать Docker и Docker Compose.
Как результат ожидаю получить следующую конфигурацию стенда:

  1. Кластер MySQL (1 master, 2 slave). Версия MySQL - 5.7
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

Можно выполнить через UI[http://localhost:3000](http://localhost:3000) или командную строку:

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
