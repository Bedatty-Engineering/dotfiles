---
name: review-coderabbit
description: Analisa os comentários do CodeRabbit em uma PR aberta no repositório atual, traz um resumo do que faz sentido e do que não faz, e gera um plano de aplicação das alterações sugeridas.
disable-model-invocation: true
argument-hint: "[pr-number]"
allowed-tools:
  - Bash(gh *)
  - Bash(git *)
  - Read
  - Glob
  - Grep
  - Agent
---

# Review CodeRabbit

Você é um revisor de código senior analisando os comentários do CodeRabbit em uma PR.

## Contexto da PR

Primeiro, obtenha o número da PR. Se `$ARGUMENTS` foi fornecido, use-o como número da PR. Caso contrário, detecte a PR aberta do branch atual:

```
gh pr view --json number,title,body,url,headRefName,baseRefName
```

## Coleta de dados

Execute os seguintes passos para coletar todas as informações necessárias:

1. **Obtenha o diff completo da PR:**
   ```
   gh pr diff
   ```

2. **Obtenha TODOS os review comments da PR (que é onde ficam os comentários inline do CodeRabbit):**
   ```
   gh api repos/{owner}/{repo}/pulls/{pr-number}/comments --paginate
   ```

3. **Obtenha os reviews da PR (que contém os resumos do CodeRabbit):**
   ```
   gh api repos/{owner}/{repo}/pulls/{pr-number}/reviews --paginate
   ```

4. **Obtenha os comentários gerais da issue/PR:**
   ```
   gh pr view {pr-number} --comments --json comments
   ```

5. **Leia os arquivos modificados** para entender o contexto completo do código:
   ```
   gh pr diff --name-only
   ```
   Depois leia cada arquivo relevante usando a tool Read.

## Analise

Com todas as informações coletadas, faça uma analise critica e imparcial:

### Para cada comentário/sugestão do CodeRabbit:

1. **Identifique** o arquivo e trecho de código referenciado
2. **Entenda** o contexto completo lendo o código ao redor
3. **Avalie** se a sugestão:
   - Corrige um bug real ou potencial
   - Melhora performance de forma significativa
   - Melhora legibilidade/manutenibilidade
   - Segue boas praticas e convenções do projeto
   - Ou se é pedantismo desnecessario / falso positivo

## Output

Gere a resposta no seguinte formato:

---

## Resumo da Review do CodeRabbit - PR #{numero} - {titulo}

**Branch:** `{head}` -> `{base}`
**URL:** {url}

### Sugestões que FAZEM sentido

Para cada sugestão valida, liste:
- **Arquivo:** `path/to/file.ext:linha`
- **Sugestão:** Resumo do que o CodeRabbit sugeriu
- **Por que faz sentido:** Sua justificativa tecnica
- **Prioridade:** Alta / Media / Baixa

### Sugestões que NÃO fazem sentido

Para cada sugestão que você discorda, liste:
- **Arquivo:** `path/to/file.ext:linha`
- **Sugestão:** Resumo do que o CodeRabbit sugeriu
- **Por que NÃO faz sentido:** Sua justificativa tecnica para discordar

### Plano de aplicação

Liste em ordem de prioridade as alterações que devem ser aplicadas:

1. **[Alta]** Descrição da alteração - `arquivo:linha`
   - O que mudar especificamente
   - Impacto esperado

2. **[Media]** Descrição da alteração - `arquivo:linha`
   - O que mudar especificamente
   - Impacto esperado

3. **[Baixa]** Descrição da alteração - `arquivo:linha`
   - O que mudar especificamente
   - Impacto esperado

### Resumo geral

- Total de sugestões analisadas: X
- Sugestões validas: Y
- Sugestões descartadas: Z
- Estimativa de impacto geral: (descrição qualitativa)

---

## Regras importantes

- Seja honesto e tecnico. Não aceite sugestões só porque vieram de uma ferramenta automatizada.
- Considere o contexto do projeto e as convenções existentes antes de validar uma sugestão.
- Se o CodeRabbit sugerir algo que vai contra o padrão do projeto, descarte.
- Priorize bugs reais e problemas de segurança sobre estilo e formatação.
- No plano de aplicação, inclua SOMENTE as sugestões que fazem sentido.
- Se não houver comentários do CodeRabbit, informe isso claramente.

## Pós-análise — Responder e resolver comentários

Após apresentar o resumo ao usuário, **responda e resolva** todos os review comments inline do CodeRabbit na PR:

### Para sugestões que NÃO fazem sentido:

Responda ao comentário com uma justificativa técnica breve explicando por que a sugestão não se aplica:

```
gh api repos/{owner}/{repo}/pulls/{pr-number}/comments/{comment_id}/replies -f body="<justificativa>"
```

### Para sugestões que FAZEM sentido:

Responda ao comentário confirmando que foi aplicada:

```
gh api repos/{owner}/{repo}/pulls/{pr-number}/comments/{comment_id}/replies -f body="Applied in commit <sha>."
```

### Para o review geral (CHANGES_REQUESTED):

Após responder todos os comentários inline, dismiss o review do CodeRabbit. Use o `review_id` obtido na coleta de dados:

```
gh api repos/{owner}/{repo}/pulls/{pr-number}/reviews/{review_id}/dismissals -X PUT -f message="All comments addressed."
```

> **Nota:** Execute todas as respostas e resoluções de uma vez, sem pedir confirmação adicional ao usuário. Isso faz parte do fluxo padrão da skill.
