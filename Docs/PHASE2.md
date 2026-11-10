# Fase 2 — Users

## Resultado

Implementada e validada em macOS com Apple Swift 6.4. Antes de adicionar Users, a Fase 1 compilou e seus 11 testes passaram. Na revisão final da Fase 2, o build terminou com exit code 0 e os **33 testes em 5 suites passaram**, incluindo os testes existentes. Não houve execução em Linux nem smoke test com servidor TCP externo.

A Fase 3 não foi iniciada. Users possui autorização pronta e testada, mas ainda não há middleware que autentique clientes reais: chamadas externas às rotas Users retornam 401. Nenhum login temporário foi implementado.

## Arquivos e responsabilidades

```text
Sources/App/
  Core/Security/
    UserIdentity.swift
    VaporPasswordHasher.swift
  Database/Migrations/
    CreateUsers.swift
    registerMigrations.swift              # Atualizado
  Modules/Users/
    Domain/
      User.swift
      UserInputRules.swift
      UserRepository.swift
    Application/
      UserService.swift
    Infrastructure/
      UserModel.swift
      FluentUserRepository.swift
    Presentation/
      UserDTOs.swift
      UserErrorMiddleware.swift
      UserController.swift
  configure.swift                        # Configura bcrypt
  routes.swift                           # Compõe service e controller
Tests/AppTests/
  UserTests.swift
  UserInputRulesTests.swift
Docs/
  API.md
  DATABASE.md
  PHASE1.md                              # Atualizado com validação posterior
  PHASE2.md
README.md                                # Estado, contratos e comandos atualizados
Package.resolved                         # Lockfile existente preservado
AGENTS.md                                # Preservado
```

Domain/Application usam Foundation e contratos próprios. O service recebe repository e hasher explicitamente; Infrastructure adapta Fluent e Vapor. Model não implementa `Content`, e o DTO público não contém credenciais. A criação interna fixa papel `member`; autorização consulta o papel persistido e o status atual em cada operação.

Nenhuma dependência foi adicionada. Permanecem Vapor 4.122.3, Fluent 4.13.0 e FluentSQLiteDriver 4.9.0 no lockfile. Bcrypt já é parte do Vapor e roda no thread pool por `AsyncPasswordHasher`. Produção usa custo 12; fixtures de teste usam bcrypt real com custo 4.

## Funcionalidades e contratos

- Criação interna com validação, email normalizado e senha com hash.
- Constraint SQL de unicidade, inclusive quando uma consulta prévia não detecta duplicidade.
- Consulta por UUID e atualização parcial de nome/email para proprietário ou administrador ativo.
- Desativação lógica sem apagar o usuário ou liberar seu email.
- Listagem administrativa paginada com limites, ordenação estável e snapshot transacional de contagem/itens.
- Proteção contra alteração de papel, status e hash pelo DTO de perfil.
- Tradução de erros para HTTP, sem detalhes de persistência.

Rotas adicionadas: `GET /api/v1/users`, `GET /api/v1/users/:userID`, `PATCH /api/v1/users/:userID` e `DELETE /api/v1/users/:userID`. Health permanece disponível. Consulte [API.md](API.md) e [DATABASE.md](DATABASE.md).

## Comandos executados e limitações do executor

`swift build` sem ajustes encontrou restrições de escrita no cache global. As dependências, antes indisponíveis, foram reutilizadas do cache local do indexador; `Package.resolved` já estava presente no início desta continuidade. A tentativa com o build system padrão também encontrou restrição na criação de arquivos temporários durante compilação de bibliotecas C.

A configuração abaixo permitiu compilar e testar, sem suprimir erros de Swift nem mudar o modo de linguagem:

```bash
mkdir -p .build/tmp
export TMPDIR="$PWD/.build/tmp"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swift-cache"
swift build --disable-sandbox --build-system native --jobs 4
swift test --disable-sandbox --build-system native --jobs 4
```

O toolchain emite aviso de depreciação de `--build-system native`, além de avisos de cache global sem permissão. Essas opções são uma adaptação deste executor restrito; fora dele, tente primeiro `swift build` e `swift test` normalmente. Não foram desabilitadas verificações de concorrência, type checking ou testes.

Na primeira compilação dos testes novos, uma closure que continha somente macros de teste não inferiu `throws`. A assinatura foi declarada explicitamente como `async throws`, e a suite foi executada novamente com sucesso. Não houve supressão do diagnóstico.

Logs locais, ignorados pelo Git:

- `.build/phase1-build.log` e `.build/phase1-test.log`: baseline aprovado antes de Users.
- `.build/phase2-build.log`: build final aprovado.
- `.build/phase2-test.log`: 33 testes aprovados.

## Cobertura verificada

Criação e hash; validação de email/nome/senha; duplicidade no service, repository e constraint SQL; chamadas anônimas e headers forjados; perfil próprio sem credenciais; bloqueio de leitura/edição/desativação de outra conta; bloqueio de listagem para membros; edição parcial e proteção de privilégios; conflito de email sem alteração parcial; desativação e bloqueio posterior; gestão administrativa; paginação; revogação de papel e status; IDs e queries inválidos; autorização direta no service; foreign keys em runtime; erro de schema sem detalhes internos; aplicação, reaplicação e rollback de migration em banco isolado.

Os testes anteriores também verificam persistência em arquivo após reinicialização e isolamento entre aplicações. `data/` foi inspecionado após os testes e contém somente `.gitkeep`. A migration foi exercitada por `autoMigrate()` nos testes; não foi aplicada a um banco real de desenvolvimento.

## Próxima etapa

Mediante autorização, implementar a Fase 3: registro/login, JWT com validação de claims, refresh tokens opacos com hash persistido, rotação, revogação, detecção de reutilização e preenchimento confiável de `UserIdentity`. Definir também um processo seguro para provisionamento administrativo, sem promoção por registro público.

Envelope central de erros, rate limiting e demais requisitos transversais seguem para suas fases previstas. OpenAPI, documentação completa, atualização específica de `AGENTS.md`, CI, Docker e verificação Linux permanecem pendentes. Esta entrega não é uma liberação para produção.
