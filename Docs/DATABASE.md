# Banco de dados — Fase 2

## Armazenamento

Desenvolvimento usa SQLite em `./data/vapor.sqlite`, relativo ao diretório de execução. Produção exige `DATABASE_PATH` explícito. O diretório pai é criado, sem apagar arquivos existentes. Foreign keys são habilitadas em cada conexão pelo SQLiteKit. Logs SQL estão desativados.

Testes usam configurações exclusivas `.memory`; o SQLiteKit pode implementá-las como arquivos temporários exclusivos. O teste de persistência usa um arquivo em diretório temporário próprio. Nenhum teste aponta para `data/vapor.sqlite`.

## Schema `users`

| Campo           | Tipo lógico | Restrição                                      |
| --------------- | ----------- | ---------------------------------------------- |
| `id`            | UUID        | Chave primária                                 |
| `name`          | String      | Obrigatório                                    |
| `email`         | String      | Obrigatório, índice único `users_email_unique` |
| `password_hash` | String      | Obrigatório, bcrypt; nunca serializado em HTTP |
| `is_active`     | Bool        | Obrigatório, criação pelo service usa `true`   |
| `role`          | String      | Obrigatório; service cria somente `member`     |
| `created_at`    | Date        | Obrigatório, definido na criação               |
| `updated_at`    | Date        | Obrigatório, atualizado nas mutações           |

O service e o repository normalizam emails antes de gravar. A constraint SQL garante unicidade inclusive quando uma consulta prévia não detecta uma inserção concorrente. SQL manual e futuros importadores devem respeitar a mesma normalização; a collation padrão do SQLite não substitui essa regra.

Não há API para promover administradores. O valor de papel é interpretado com enum fechado (`member`/`admin`); um valor desconhecido falha sem conceder privilégios. A definição futura de provisionamento administrativo deve evitar credenciais padrão e promoção pelo registro público.

Datas são explícitas em vez de opcionais geradas por wrappers, mantendo entidades de domínio completas. Atualizações de perfil alteram somente nome/email e `updated_at`; não regravam papel, hash ou status a partir de uma cópia antiga. Desativação preserva o registro e o email único.

## Migrations

`CreateUsers` é uma `AsyncMigration` registrada em `Sources/App/Database/Migrations/registerMigrations.swift`.

```bash
swift run App migrate
swift run App serve
```

Migrations não rodam automaticamente na inicialização. O Fluent registra as migrations aplicadas, de forma que uma nova execução não recria o schema. O método `revert` remove a tabela e é destrutivo: foi exercitado apenas em banco isolado de teste. Não reverta ambientes com dados sem autorização e backup.

Crie uma nova migration para cada alteração de schema; não reescreva migrations aplicadas. Mantenha registro em ordem de dependência. Teste aplicação, reaplicação e rollback isolado quando houver reversão segura.

## Backup e restauração

Use a API/ferramenta de backup do SQLite ou pare as escritas antes de copiar o banco. Uma cópia apenas do arquivo principal durante atividade pode omitir dados do journal/WAL. Armazene backups com acesso restrito fora do Git e valide restauração em outro caminho. Não restaure por cima de dados existentes sem autorização. Referência: [SQLite Online Backup API](https://www.sqlite.org/backup.html).

## Evolução para PostgreSQL

O contrato `UserRepository` não depende de Fluent. O adapter atual usa Fluent, mas isso não garante portabilidade automática de migrations e semântica SQL. Ao substituir o driver, revise UUIDs, booleanos, timestamps/fuso, collation e unicidade de email, tratamento de constraints, DDL, locks e isolamento transacional. Teste paginação e inserções concorrentes no novo banco. PostgreSQL não está instalado nem declarado como dependência.
