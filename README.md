# oficina-infra-k8s

Infraestrutura base na AWS (Terraform): VPC, EC2 com k3s, EIP, ECR, security groups e agentes de
observabilidade — Tech Challenge FIAP, Fase 3.

Repositório criado na etapa E0 a partir do histórico de `oficina/infra/` do monorepo
[tech-challenge-fiap](https://github.com/victorduarte31/tech-challenge-fiap). O RDS vive em
[oficina-infra-database](https://github.com/victor-duarte-mendonca/oficina-infra-database).

## Ambientes e branches

| Branch    | Environment   | Workspace Terraform | Deploy                      |
|-----------|---------------|---------------------|-----------------------------|
| `homolog` | `homologacao` | `hml`               | automático no merge         |
| `main`    | `producao`    | `prod`              | automático, com aprovação   |

`main` e `homolog` só recebem merge por PR (squash) com os checks `validate` e `plan` verdes.

## Credenciais por sessão

As credenciais do AWS Academy expiram a cada sessão. Publique-as uma vez como *organization
secrets* — os 4 repositórios as leem:

```bash
export AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... AWS_SESSION_TOKEN=...
./scripts/set-aws-session-secrets.sh
```

## Ordem de bootstrap (por sessão)

1. `set-aws-session-secrets.sh`
2. **este repositório** → `apply` (VPC, EIP, ECR → SSM)
3. `oficina-infra-database` → `apply`
4. `oficina-app` → deploy
5. `oficina-auth-lambda` → deploy
6. **destroy na ordem inversa ao final da sessão** — RDS, EIP e API Gateway continuam cobrando após o "End Lab".

Conteúdo completo (diagrama, custos, workflows de apply/destroy) entra em E2 (spec 06).
