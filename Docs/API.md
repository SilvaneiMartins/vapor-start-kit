# API — Fases 1 e 2

Prefixo: `/api/v1`. JSON nas entradas e saídas, exceto respostas 204 sem corpo. Limite padrão de corpo: 16 KB. UUIDs usam a representação textual padrão; datas seguem a codificação ISO 8601 do Vapor.

## Estado da autenticação

As rotas Users exigem `UserIdentity`, preenchida exclusivamente por middleware confiável. A Fase 3 implementará validação JWT e criação dessa identidade. Até lá, todas as chamadas externas a Users retornam 401; headers `X-User-ID`, `X-Role` e tokens arbitrários não autenticam ninguém.

Os testes HTTP instalam uma fixture de identidade somente no target de testes. O código de produção não possui equivalente, administrador padrão ou endpoint de promoção de papel. O service relê papel e status da conta a cada operação protegida.

## Rotas

| Método | Caminho          | Permissão                                 | Resposta                          |
| ------ | ---------------- | ----------------------------------------- | --------------------------------- |
| GET    | `/health`        | Pública                                   | 200 com status, serviço e versão  |
| GET    | `/health/ready`  | Pública                                   | 200 ou 503, sem detalhes internos |
| GET    | `/users`         | Administrador ativo                       | 200 com itens e metadados         |
| GET    | `/users/:userID` | Proprietário ativo ou administrador ativo | 200 com perfil                    |
| PATCH  | `/users/:userID` | Proprietário ativo ou administrador ativo | 200 com perfil atualizado         |
| DELETE | `/users/:userID` | Proprietário ativo ou administrador ativo | 204 após desativação lógica       |

Um membro não pode consultar, editar ou desativar outro UUID. A autorização precede a consulta ao usuário alvo: um UUID alheio válido retorna 403 para membros, mesmo se não existir. Administradores recebem 404 para um alvo inexistente.

Administradores podem consultar contas inativas e desativá-las novamente. Não é permitido editar perfil de conta inativa. A conta desativada não pode continuar acessando a API, e seu email permanece reservado. Não existe exclusão física ou reativação nesta fase.

## Perfil e atualização

Resposta de perfil (não contém hash, senha, papel nem tokens):

```json
{
  "id": "f36c3e43-b7ad-4b5c-9daa-fdf174f847b2",
  "name": "Alice Example",
  "email": "alice@example.com",
  "isActive": true,
  "createdAt": "2026-11-09T12:00:00Z",
  "updatedAt": "2026-11-09T12:00:00Z"
}
```

Corpo de PATCH:

```json
{"name":"Alice Updated","email":"alice.updated@example.com"}
```

Nome e email são opcionais individualmente, mas pelo menos um deve estar presente e não nulo. Campos desconhecidos são ignorados; `role`, `isActive`, `passwordHash`, UUID e timestamps não são atualizáveis pelo DTO. Nome é aparado e deve ter 2–100 caracteres sem controles. Email é aparado, convertido para minúsculas e validado como endereço ASCII de até 254 bytes, com domínio contendo ponto; não há suporte a endereços internacionais ou local-part entre aspas.

## Paginação

`GET /api/v1/users?page=1&perPage=20`

- `page`: padrão 1, intervalo 1–1.000.000.
- `perPage`: padrão 20, intervalo 1–100.
- Ordenação por `createdAt`, seguida de UUID, ambas ascendentes.
- Inclui contas ativas e inativas, acessível somente a administradores.
- Página além do total retorna `items: []`, com o total preservado.
- Contagem e itens são consultados na mesma transação. Inserções entre requisições podem deslocar páginas; não é paginação por cursor.

```json
{"items":[],"metadata":{"page":1,"perPage":20,"total":0}}
```

## Erros

Ainda é usado o formato nativo do Vapor, por exemplo:

```json
{"error":true,"reason":"Authentication required"}
```

| Código | Situação                                                |
| ------ | ------------------------------------------------------- |
| 400    | UUID, query, JSON ou dados inválidos; perfil vazio      |
| 401    | Sem identidade, identidade inexistente ou conta inativa |
| 403    | Sem permissão ou tentativa de editar conta inativa      |
| 404    | Alvo inexistente para solicitante autorizado            |
| 409    | Email já cadastrado, incluindo contas desativadas       |
| 413    | Corpo acima do limite configurado                       |
| 415    | Content-Type não suportado pelo decodificador           |
| 500    | Falha interna; sem SQL, caminhos ou credenciais         |

O envelope central com `code`, `details` e `requestId` pertence à Fase 4. A especificação OpenAPI será criada na Fase 5.

## Exemplos executáveis nesta fase

Com o servidor iniciado:

```bash
curl -i http://127.0.0.1:8080/api/v1/health
curl -i http://127.0.0.1:8080/api/v1/health/ready
curl -i 'http://127.0.0.1:8080/api/v1/users?page=1&perPage=20'
```

A última chamada deve retornar 401. Os contratos de sucesso de Users são exercitados pelos testes HTTP; não existe ainda um fluxo externo para obter credenciais válidas. `POST /auth/register`, login e refresh não foram implementados.
