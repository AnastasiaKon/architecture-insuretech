# architecture-insuretech

Проектная работа спринта 8 курса «Архитектор ПО» (Яндекс Практикум): архитектура InsureTech под рост нагрузки.

| Директория | Содержимое |
|---|---|
| `Task1/` | `InureTech_технологическая архитектура_to-be.drawio` - целевая технологическая архитектура (Yandex Cloud, 3 зоны доступности, Managed Kubernetes, Managed PostgreSQL HA, DR). Комментарии с обоснованием решений - на схеме |
| `Task2/` | Манифесты `deployment.yaml`, `service.yaml`, `hpa.yaml`, `locustfile.py`, скрипт `run.sh`; `evidence/` - скриншоты и логи масштабирования |
| `Task3/` | `Task3_problems_and_risks.md` - проблемы и риски текущих интеграций; `Task3_InsureTech_C4_container-diagram_event-driven.drawio` - диаграмма контейнеров после перехода на event streaming |
| `Task4/` | `Task4_InsureTech_C4_container-diagram_osago.drawio` - диаграмма с `osago-aggregator`, интеграциями и паттернами отказоустойчивости |
| `Task5/` | `Task5_client-info.graphql` - GraphQL-схема сервиса client-info |
| `Task6/` | - |

Схемы `.drawio` открываются в draw.io / diagrams.net. Схемы заданий 3 и 4 выполнены в нотации C4 (встроенная библиотека draw.io), задание 1 - с библиотеками иконок Yandex Cloud.
