# Fase 1 — Foundation

> Atualização na Fase 2: as dependências tornaram-se disponíveis no cache local e `Package.resolved` foi gerado. O build da Fase 1 passou e os 11 testes originais foram aprovados antes da implementação de Users. Os bloqueios abaixo são o registro histórico da primeira tentativa. Foreign keys também foram incluídas na validação da Fase 2; veja [PHASE2.md](PHASE2.md).

## Escopo entregue em código

Pacote executável `App`, Swift 6, Vapor 4, Fluent e SQLite; configuração de ambiente; registro central de migrations (ainda sem schema de negócio); health e readiness; testes Swift Testing/VaporTesting; README inicial e exclusões de arquivos sensíveis.

O `AGENTS.md` preexistente foi lido e preservado. Sua revisão específica para a arquitetura final está prevista na Fase 5. Nenhum Git foi inicializado, nenhuma dependência de infraestrutura externa foi instalada e nenhum arquivo de dados preexistente foi removido.

## Ambiente inspecionado em 09/11/2026

- Diretório inicial: somente `AGENTS.md`.
- `swift --version`: Apple Swift 6.4, target arm64-apple-macosx27.0.0.
- `xcode-select -p`: `/Applications/Xcode.app/Contents/Developer`.
- `xcodebuild -version`: Xcode 27.0, build 27A266a.
- `xcrun --show-sdk-version`: 27.0.
- `vapor --version`: comando não encontrado; Toolbox opcional para este pacote.

## Evidências de validação

| Comando | Resultado |
| --- | --- |
| `swift build` | Falhou antes de compilar: escrita no cache global de módulos proibida pelo ambiente |
| `swift test` | Falhou antes de executar testes pelo mesmo bloqueio de cache |
| Build com caches dentro de `.build` | O sandbox interno do SwiftPM também encontrou `sandbox_apply: Operation not permitted` |
| Build/test com caches locais e `--disable-sandbox` | Manifesto processado, resolução de dependências bloqueada; erro de repositório ausente no cache após tentativas de fetch |
| Build com `--disable-dependency-cache` | Confirmou o motivo: `Could not resolve host: github.com` ao clonar Vapor |
| `swift package --disable-sandbox dump-package` com caches locais | Sucesso, exit code 0; descrição gerada em `.build/package-description.json` |
| `swiftc -frontend -parse` sobre todos os arquivos Swift de Sources e Tests | Sucesso, exit code 0; apenas análise sintática, sem checagem de tipos ou linkedição |

As variáveis usadas nas tentativas com cache local foram:

```bash
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swift-cache"
swift build --disable-sandbox --disable-dependency-cache
swift test --disable-sandbox --cache-path .build/package-cache
```

Essas opções diagnosticam limitações deste executor; não são os comandos padrão de desenvolvimento. Não alteram o modo Swift 6 nem suprimem erros do código. Não houve execução bem-sucedida de build ou testes, nem teste HTTP manual. Nenhum teste está declarado aprovado.

## Testes escritos

- Health: status, identificador público e versão.
- Readiness: conexão com SQLite isolado e falha injetada retornando 503 sem detalhes internos; liveness permanece independente.
- Configuração: defaults locais, independência das variáveis externas em testing, portas inválidas, caminho obrigatório em produção, conflito de ambiente e configurações inválidas.
- Banco: isolamento entre duas aplicações e persistência em arquivo temporário após reinicialização.

O teste de readiness indisponível usa uma implementação do contrato `ReadinessChecking`. Na primeira entrega, os testes de banco estavam sem execução. Na Fase 2, persistência, isolamento e foreign keys passaram em runtime; também foi verificado que a falha real de schema em Users não expõe SQL. Falhas reais de conectividade no endpoint de readiness ainda não foram simuladas.

## Decisões e fontes oficiais

- Versões mínimas e inicialização baseadas no [template oficial do Vapor](https://github.com/vapor/template) e nas [releases do driver SQLite](https://github.com/vapor/fluent-sqlite-driver/releases).
- Testes seguem [Swift Testing com VaporTesting](https://docs.vapor.codes/advanced/testing/).
- Ambiente segue [Environment e dotenv](https://docs.vapor.codes/basics/environment/); `APP_ENV` funciona como validação de consistência, não substitui o seletor de ambiente do Vapor.
- Migrations seguem o [comando explícito do Fluent](https://docs.vapor.codes/fluent/migration/).
- Foreign keys são habilitadas pela configuração do SQLiteKit em cada conexão. A opção `.memory` pode usar um arquivo temporário exclusivo conforme a [implementação oficial](https://github.com/vapor/sqlite-kit/blob/main/Sources/SQLiteKit/SQLiteConnectionSource.swift).

JWTKit será introduzido na Fase 3, quando tiver consumidor real. Não há secret obrigatório enquanto não existir autenticação. A aplicação não deve ser considerada pronta para produção nesta fase.

## Pendências registradas na entrega inicial (histórico)

1. Resolver dependências em ambiente com acesso ao GitHub e gerar `Package.resolved`.
2. Executar `swift build` e `swift test`; corrigir eventuais erros de tipos, integração ou testes antes de avançar.
3. Executar migrations e smoke tests HTTP em ambiente de desenvolvimento descartável.
4. Confirmar persistência, isolamento dos testes e enforcement de foreign keys em runtime.
5. Verificar Linux na fase de entrega.

Na primeira entrega, a Fase 1 permaneceu pendente de validação. Na continuidade autorizada, build e testes passaram antes de iniciar a Fase 2. Linux e smoke tests por servidor TCP permanecem sem validação neste executor.
