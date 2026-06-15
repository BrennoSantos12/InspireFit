# InspireFit — Diagramas do Projeto de Extensão

App de academia em **Flutter**, **offline**, com banco **SQLite local** (sqflite),
sem backend e sem login (usuário único). Gerência de estado com **provider**.

> Os diagramas abaixo estão em [Mermaid](https://mermaid.live). Para gerar uma imagem,
> cole o código em <https://mermaid.live> e exporte como PNG/SVG.

---

## 1. Diagrama Entidade-Relacionamento (banco de dados)

```mermaid
erDiagram
    days ||--o{ training_plans : "tem"
    trainings ||--o{ training_plans : "tem"
    training_plans ||--o{ training_plan_exercises : "contém"
    exercises ||--o{ training_plan_exercises : "usado em"
    training_plans ||--o{ training_sessions : "realizada como"
    training_sessions ||--o{ training_executions : "registra"
    training_plan_exercises ||--o{ training_executions : "executado em"

    days {
        int id PK
        text name "ex.: Segunda-feira"
    }
    trainings {
        int id PK
        text name "ex.: Treino A - Peito"
    }
    exercises {
        int id PK
        text name UK
        text type "tipo do exercício"
    }
    training_plans {
        int id PK
        int training_id FK
        int day_id FK
    }
    training_plan_exercises {
        int id PK
        int training_plan_id FK
        int exercise_id FK
    }
    training_sessions {
        int id PK
        int training_plan_id FK
        text performed_date "data realizada"
    }
    training_executions {
        int id PK
        int training_session_id FK
        int training_plan_exercise_id FK
        int sets_done "séries feitas"
        real reps "repetições"
        real weight "carga (kg)"
    }
```

**Leitura:** uma *ficha* (`training_plans`) liga um **treino** a um **dia** e reúne vários
**exercícios** (`training_plan_exercises`). Cada vez que o usuário treina, cria-se uma
**sessão** (`training_sessions`), e cada exercício feito vira uma **execução**
(`training_executions`) com séries, repetições e carga — base dos relatórios de progresso.

---

## 2. Arquitetura em camadas

```mermaid
flowchart TD
    subgraph UI["Camada de Apresentação (screens)"]
        Home[Home]
        Fichas[Fichas]
        Criar["Criar / Editar Ficha"]
        Sessao["Sessão (timer 120s)"]
        Relatorios[Relatórios]
    end

    subgraph State["Gerência de Estado (provider)"]
        MP[MultiProvider]
    end

    subgraph Repos["Camada de Domínio (repositories)"]
        Catalog[CatalogRepository]
        Plan[TrainingPlanRepository]
        Session[TrainingSessionRepository]
        Report[ReportRepository]
    end

    subgraph Data["Camada de Dados"]
        DBH[DatabaseHelper]
        DB[(SQLite local\ninspirefit.db)]
        Seeds[Seeds: dias, treinos, exercícios]
    end

    UI --> MP --> Repos
    Catalog --> DBH
    Plan --> DBH
    Session --> DBH
    Report --> DBH
    DBH --> DB
    Seeds -. onCreate .-> DB
```

---

## 3. Casos de uso (o que o usuário faz)

```mermaid
flowchart LR
    User((Usuário))
    User --> UC1[Ver fichas de treino]
    User --> UC2[Criar / editar ficha]
    User --> UC3[Executar sessão de treino]
    UC3 --> UC3a[Usar timer de descanso 120s]
    UC3 --> UC3b[Registrar séries, reps e carga]
    User --> UC4[Editar sessão realizada]
    User --> UC5[Ver relatórios]
    UC5 --> UC5a[Aderência ao plano]
    UC5 --> UC5b[Progresso de carga]
```

---

## 4. Fluxo de navegação de telas

```mermaid
flowchart LR
    Home[Home] --> Fichas[Fichas]
    Home --> Relatorios[Relatórios]
    Fichas --> Criar["Criar Ficha"]
    Fichas --> Editar["Editar Ficha"]
    Fichas --> Sessao["Sessão de Treino\n(timer 120s)"]
    Sessao --> EditSessao["Editar Sessão"]
    Relatorios --> Aderencia[Aderência]
    Relatorios --> Progresso[Progresso]
```

