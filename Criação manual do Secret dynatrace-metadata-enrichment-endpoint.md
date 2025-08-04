# Dynatrace - Criação manual do Secret `dynatrace-metadata-enrichment-endpoint`

Este documento descreve como criar manualmente o Secret `dynatrace-metadata-enrichment-endpoint` com conteúdo válido, útil em casos onde:

- O Dynatrace OneAgent foi instalado diretamente nos nodes (sem Operator);
- Os Pods referenciam o volume `metadata-enrichment-endpoint`, mas o Secret não existe;
- Você deseja parar os erros `MountVolume.SetUp failed` na UI da Dynatrace;
- Ou deseja simular o comportamento correto de enriquecimento de metadados sem usar o Operator.

---

## 1. Criar o arquivo `enrichment.json`

Crie um arquivo chamado `enrichment.json` com o seguinte conteúdo:

```json
{
  "enrichment.endpoint": "https://dynatrace-kubernetes-monitoring.dynatrace.svc.cluster.local/api",
  "cluster.id": "SEU-ID",
  "cluster.name": "productionk8s"
}

```

<strong> enrichment.endpoint:</strong> URL interna do serviço de enriquecimento do Dynatrace Operator.

<strong>cluster.id:</strong> Identificador único do cluster (pode ser um UUID ou string).

<strong>cluster.name:</strong> Nome amigável que será exibido na UI Dynatrace.

## 2. Executar script PowerShell para aplicar o Secret nos namespaces necessários

Este script localiza todos os namespaces onde há Pods que referenciam o Secret e aplica o enrichment.json corretamente em todos eles:

```ps1 
# Caminhos personalizados
$kubectl = ".\kubectl.exe"
$kubeconfig = "--kubeconfig=.\kubeconfig-production.yaml"
$secretName = "dynatrace-metadata-enrichment-endpoint"
$jsonPath = ".\enrichment.json"

# Carrega os Pods
$podsJson = & $kubectl get pods --all-namespaces -o json $kubeconfig | ConvertFrom-Json

# Encontra namespaces que usam o Secret
$namespaces = $podsJson.items |
    Where-Object {
        $_.spec.volumes -ne $null -and
        $_.spec.volumes.secret.secretName -contains $secretName
    } |
    Select-Object -ExpandProperty metadata |
    Select-Object -ExpandProperty namespace -Unique

# Cria ou atualiza o Secret em cada namespace
foreach ($ns in $namespaces) {
    Write-Host "`nCriando Secret corretamente no namespace: $ns"
    & $kubectl create secret generic $secretName `
        --from-file="enrichment.json=$jsonPath" `
        -n $ns `
        $kubeconfig `
        --dry-run=client -o yaml | & $kubectl apply -f - $kubeconfig
}
```

## Observações

* Não causa indisponibilidade nos Pods.
* Corrige os erros de volume mount reportados no Dynatrace.
* Simula o comportamento esperado quando não se utiliza o Dynatrace Operator.
* Caso venha a usar o Operator futuramente, ele substituirá esse Secret automaticamente com os valores corretos.

## Verificar Secrets criados 
Após a execução, você pode verificar:

```bash 
kubectl get secrets --all-namespaces -o jsonpath='{range .items[?(@.metadata.name=="dynatrace-metadata-enrichment-endpoint")]}{.metadata.namespace}{"\n"}{end}'
```

## Requisitos
* kubectl configurado corretamente com acesso ao cluster.
* enrichment.json salvo localmente.
* PowerShell instalado (ambiente Windows).
* (Opcional) Dynatrace Operator rodando se quiser que o endpoint seja realmente funcional.

## Resultado Esperado
* Erros de volume mount deixam de aparecer.
* Se OneAgent estiver injetado dentro dos Pods, ele consegue ler metadados.
* Ambiente mais limpo e pronto para futuras integrações com o Operator.

