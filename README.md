# Vapor Starter Kit

Fundação de backend Swift para futuros clientes iOS, macOS, Android e Web, organizada como monólito modular.

**Estado: Fases 1 e 2 implementadas.** Build e testes foram executados com ajustes de cache e build system necessários neste executor. Não está liberada para produção: autenticação JWT, refresh tokens, envelope central de erros, rate limiting, CORS, OpenAPI, CI e Docker pertencem às próximas fases. Consulte os registros da [Fase 1](Docs/PHASE1.md) e [Fase 2](Docs/PHASE2.md).

As rotas Users exigem uma identidade autenticada. Como o autenticador da Fase 3 ainda não existe, chamadas externas a essas rotas retornam **401**, inclusive com um Bearer arbitrário. Não há login provisório, senha padrão ou bypass de segurança.

## Funcionalidades desta fase

- Inicialização assíncrona do Vapor e encerramento dos recursos.
- Configuração validada de host, porta, ambiente, logs e banco.
- SQLite persistente em desenvolvimento, diretório criado automaticamente e foreign keys habilitadas por conexão.
- Configuração SQLite exclusiva por aplicação de teste, sem consultar o caminho de desenvolvimento.
- Health e readiness com resposta 503 quando a conexão obrigatória falha.
- Users com migration, repository, service e DTOs independentes dos modelos Fluent.
- Normalização e unicidade de email, bcrypt assíncrono, edição de perfil e desativação lógica.
- Autorização por proprietário ou administrador ativo; listagem global exclusiva de administradores.
- Testes de contratos HTTP, configuração, isolamento, persistência, autorização e integridade do banco.

## Tecnologias e requisitos

Swift 6.3 ou superior, modo de linguagem Swift 6, macOS 13 ou superior ou Linux com toolchain compatível. Dependências diretas:

| Pacote | Versão mínima | Finalidade |
| --- | --- | --- |
| Vapor | 4.121.4 | HTTP, ciclo de vida e VaporTesting |
| Fluent | 4.13.0 | ORM e comando de migrations |
| FluentSQLiteDriver | 4.9.0 | Persistência SQLite |

Swift Testing é fornecido pelo toolchain. Não há serviços externos. A resolução permite atualizações compatíveis dentro da versão principal. `Package.resolved` foi gerado e está incluído: Vapor 4.122.3, Fluent 4.13.0 e FluentSQLiteDriver 4.9.0. Nenhuma dependência foi adicionada para a Fase 2; bcrypt já integra o Vapor.

## Preparação no macOS

Instale um toolchain compatível seguindo o [guia oficial do Swift](https://www.swift.org/install/macos/) e as ferramentas do Xcode. Confira:

```bash
swift --version
xcode-select -p
xcodebuild -version
```

Se as ferramentas de desenvolvimento ainda não estiverem instaladas, use `xcode-select --install`. O Vapor Toolbox é opcional: este projeto usa diretamente Swift Package Manager. Sua instalação está descrita na [documentação oficial do Vapor](https://docs.vapor.codes/install/macos/).

## Instalação e configuração

Execute a partir da raiz do projeto, com acesso ao GitHub:

```bash
cp -n .env.example .env
swift package resolve
swift build
```

O Vapor carrega `.env` e `.env.<ambiente>`; variáveis do processo prevalecem. Não use `source .env`: o arquivo segue a sintaxe dotenv e contém valores com espaços.

| Variável | Comportamento atual |
| --- | --- |
| `APP_NAME` | Nome interno; padrão `Vapor Starter Kit` |
| `APP_ENV` | Verificação de consistência com o ambiente selecionado pelo Vapor |
| `APP_HOST` | Padrão `127.0.0.1` |
| `APP_PORT` | Inteiro entre 1 e 65535; padrão 8080 |
| `DATABASE_DRIVER` | Aceita somente `sqlite` |
| `DATABASE_PATH` | Padrão `./data/vapor.sqlite`; obrigatório explicitamente em produção |
| `LOG_LEVEL` | Nível válido do SwiftLog; padrão `info` |
| `JWT_SECRET`, `JWT_ACCESS_TTL_SECONDS`, `JWT_REFRESH_TTL_SECONDS` | Reservadas para a Fase 3; não utilizadas nem validadas nesta fase |

O ambiente efetivo é selecionado por `--env` ou `VAPOR_ENV`, conforme o Vapor. `APP_ENV` sozinho **não troca o ambiente**; se informado, deve coincidir com ele. Exemplo de configuração de produção futura: `APP_ENV=production VAPOR_ENV=production DATABASE_PATH=/caminho/persistente/vapor.sqlite`. Ainda é necessário concluir as fases de segurança antes de publicar a API.

Em testes, a configuração ignora variáveis externas e usa SQLite isolado. O driver pode implementar `.memory` com arquivos temporários exclusivos; isso não acessa `data/vapor.sqlite`.

## SQLite e migrations

O diretório pai do banco é criado ao configurar a aplicação. O arquivo é aberto sob demanda, ao adquirir a primeira conexão, por exemplo em readiness. A migration `CreateUsers` cria `users` com email único, credenciais protegidas, papel e timestamps obrigatórios.

```bash
swift run App migrate
swift run App serve
```

O comando `migrate` é fornecido pelo Fluent. A migration `CreateUsers` está registrada e será aplicada após confirmação. Executar o comando novamente não recria a tabela nem remove os usuários. Não há execução automática de migrations ao iniciar o servidor.

Futuras migrations devem implementar `AsyncMigration`, usar nomes como `CreateUsers` e ser registradas em ordem em `Database/Migrations/registerMigrations.swift`. Nunca edite uma migration já aplicada nem reverta dados de desenvolvimento ou produção sem autorização e backup.

Para backup, use a ferramenta de backup do SQLite ou uma cópia consistente com a aplicação parada. Não copie apenas o arquivo principal durante escritas ativas. Mantenha backups fora do repositório e teste a restauração. Consulte a [documentação de backup do SQLite](https://www.sqlite.org/backup.html).

## Endpoints implementados

| Método | Rota | Respostas |
| --- | --- | --- |
| GET | `/api/v1/health` | 200, processo respondendo |
| GET | `/api/v1/health/ready` | 200, conexão adquirida; 503, dependência indisponível |
| GET | `/api/v1/users?page=1&perPage=20` | Listagem administrativa: 200; 401/403 sem permissão |
| GET | `/api/v1/users/:userID` | Perfil: 200; proprietário ou administrador |
| PATCH | `/api/v1/users/:userID` | Atualização de nome/email: 200; proprietário ou administrador |
| DELETE | `/api/v1/users/:userID` | Desativação lógica: 204; proprietário ou administrador |

Contratos completos, paginação e códigos de erro: [Docs/API.md](Docs/API.md). Registro/login não estão expostos nesta fase; a criação de usuários existe apenas no service para integração futura.

```bash
curl -i http://127.0.0.1:8080/api/v1/health
curl -i http://127.0.0.1:8080/api/v1/health/ready
```

Resposta 200 de ambos:

```json
{"status":"ok","service":"vapor-starter-kit","version":"1.0.0"}
```

Resposta 503 de readiness:

```json
{"status":"unavailable","service":"vapor-starter-kit","version":"1.0.0"}
```

Readiness verifica aquisição de conexão, não existência de tabelas, migrations pendentes ou integridade completa do banco. Não retorna erros do driver, caminhos ou secrets. Erros Users são traduzidos em 400/401/403/404/409/500, sem detalhes SQL. O corpo ainda segue o padrão nativo do Vapor (`error` e `reason`); o envelope central e Request ID público serão implementados na Fase 4.

## Estrutura e arquitetura

```text
Package.swift
AGENTS.md                         # Guia existente, preservado
.env.example
.gitignore
README.md
Docs/                            # API, banco e registros das fases
Sources/App/
  entrypoint.swift                # Ciclo de vida assíncrono
  configure.swift                # Composição de dependências
  routes.swift                   # Prefixo /api/v1
  Core/Configuration/            # Leitura e validação de configuração
  Core/Security/                 # Adaptador bcrypt e identidade autenticada
  Database/Configuration/        # Driver e armazenamento
  Database/Migrations/           # Registro explícito de migrations
  Modules/Health/
    Domain/                      # Contrato independente de HTTP e Fluent
    Infrastructure/              # Verificação de conexão Fluent
    Presentation/                # Controller, rotas e DTOs
  Modules/Users/
    Domain/                      # User, validação e contratos
    Application/                 # UserService e autorização
    Infrastructure/              # UserModel e FluentUserRepository
    Presentation/                # Controller, DTOs e tradução de erros
Tests/AppTests/                   # Health, configuração, SQLite e Users
data/.gitkeep                    # Diretório; bancos não versionados
```

A composição injeta `DatabaseReadinessCheck` no `HealthController` pelo contrato `ReadinessChecking`. `UserService` recebe `UserRepository` e `PasswordHashing`. As regras de negócio em Domain/Application não dependem de `Request`, `Response` ou `Model` do Fluent. `UserIdentity` transporta somente o UUID; o service consulta status e papel atuais no banco em cada operação protegida. Camadas são diretórios no mesmo target, com limites mantidos por revisão; não há isolamento de compilação entre elas.

Para adicionar um módulo, crie `Modules/<Name>`, mantenha DTOs e controllers em Presentation, casos de uso em Application e implementações de repositórios em Infrastructure. Introduza protocolos somente quando isolarem dependências ou permitirem testes relevantes. Registre rotas em `routes.swift` e mantenha documentação e testes sincronizados.

## Testes

```bash
swift build
swift test
```

Os testes usam Swift Testing e VaporTesting. Cada aplicação recebe um banco isolado; o teste de persistência usa um diretório temporário exclusivo e o remove ao terminar. Os testes não apagam nem migram o banco de desenvolvimento. Não existe meta percentual de cobertura nesta fase.

Build e testes das duas fases foram executados com sucesso usando caches locais, diretório temporário no workspace e o build system nativo. Os comandos exatos e resultados estão em [Docs/PHASE2.md](Docs/PHASE2.md). Os comandos simples continuam sendo o fluxo normal fora deste executor restrito.

## Segurança e evolução

`.env`, arquivos SQLite, chaves e artefatos locais estão ignorados pelo Git. O limite padrão de corpo das rotas é 16 KB. Logs SQL estão desabilitados. Não registre headers de autorização, senhas, tokens ou secrets nas próximas fases.

Para gerar o segredo futuro, use `openssl rand -base64 48` e guarde o resultado fora do repositório. O bcrypt de produção usa custo 12; testes usam bcrypt real com custo 4 somente na fixture. Senhas têm no mínimo 12 caracteres e no máximo 72 bytes UTF-8; não são aparadas nem truncadas. Não há autenticação nem emissão de tokens nesta fase; o placeholder de `.env.example` não deve ser usado quando a autenticação for implementada.

A futura troca por PostgreSQL deverá substituir o driver na composição e revisar tipos, constraints, índices, collation de email, alterações de schema, concorrência e isolamento transacional. Fluent reduz o acoplamento, mas não elimina diferenças entre bancos. PostgreSQL não é dependência desta versão.

## Linux e entrega

Use um toolchain Swift 6.3+ compatível com a distribuição, seguindo o [guia oficial](https://www.swift.org/install/linux/), e os mesmos comandos de resolução, build e testes. A implementação não importa frameworks exclusivos da Apple. A execução em Linux ainda não foi verificada. CI, Docker e instruções completas de deploy ficam para a Fase 6.

## Troubleshooting

- `Could not resolve host: github.com`: disponibilize rede/DNS para baixar as dependências.
- Erros de cache ou `sandbox_apply`: execute os comandos em um terminal com permissões normais; não reduza as verificações do compilador.
- `APP_ENV must match`: alinhe `APP_ENV` ao `--env`/`VAPOR_ENV` escolhido.
- Erro de abertura SQLite: confira caminho e permissões do diretório persistente.
- Readiness 503: verifique disponibilidade do banco sem publicar detalhes internos na resposta.

## Roadmap e licença

Fases 1 e 2 implementadas e testadas. Próximo passo, mediante autorização: Fase 3 (Auth/JWT), Fase 4 (qualidade da API), Fase 5 (documentação completa/OpenAPI) e Fase 6 (CI/entrega). Integrações específicas de clientes móveis e Web serão documentadas junto aos contratos de autenticação.

Licença ainda não definida pelo proprietário; nenhum arquivo de licença foi adicionado.

Referências: [Swift](https://www.swift.org/documentation/), [Vapor](https://docs.vapor.codes/), [Fluent](https://docs.vapor.codes/fluent/overview/), [SQLite](https://www.sqlite.org/docs.html).
