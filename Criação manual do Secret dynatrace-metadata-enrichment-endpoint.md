# Dynatrace - Criação manual de Secrets para evitar erros de MountVolume

Este documento descreve como criar manualmente os Secrets utilizados pelo Dynatrace em ambientes onde o **OneAgent é instalado diretamente nos nodes** (sem Operator). Serve para:

- Eliminar erros como `MountVolume.SetUp failed` visíveis na UI do Dynatrace;
- Evitar ruído causado por volumes que tentam montar Secrets que não existem;
- Preparar o ambiente para compatibilidade futura com o Dynatrace Operator (se for adotado).

---

## Secret 1: `dynatrace-metadata-enrichment-endpoint`

### Quando é necessário?

- Quando os Pods montam o volume `metadata-enrichment-endpoint`, mas o Secret não existe.
- Mesmo que o OneAgent esteja no node, o erro aparece na UI da Dynatrace.

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

**enrichment.endpoint:** URL interna do serviço de enriquecimento do Dynatrace Operator.  
**cluster.id:** Identificador único do cluster (UUID ou nome único).  
**cluster.name:** Nome amigável exibido na UI do Dynatrace.

---

## 2. Executar script PowerShell para aplicar o Secret nos namespaces necessários

```powershell
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

---

## Secret 2: `dynatrace-dynakube-config`

### Quando é necessário?

- Quando o erro abaixo aparece na UI do Dynatrace:
  ```
  MountVolume.SetUp failed for volume "injection-config" : secret "dynatrace-dynakube-config" not found
  ```
- Esse Secret é usado apenas quando o Dynatrace Operator está ativo com injeção automática.  
- **Se você não usa o Operator, basta criar um dummy.**

---

### Script PowerShell para criar Secret dummy:

```powershell
# Configurações
$kubectl = ".\kubectl.exe"
$kubeconfig = "--kubeconfig=.\kubeconfig-production.yaml"
$secretName = "dynatrace-dynakube-config"
$tempFile = "$env:TEMP\dummy-injection.json"

# Cria JSON dummy
"{}" | Out-File -Encoding ASCII $tempFile

# Buscar todos os Pods
$podsJson = & $kubectl get pods --all-namespaces -o json $kubeconfig | ConvertFrom-Json

# Identificar namespaces que referenciam o Secret
$namespaces = $podsJson.items |
    Where-Object {
        $_.spec.volumes -ne $null -and
        $_.spec.volumes.secret.secretName -eq $secretName
    } |
    Select-Object -ExpandProperty metadata |
    Select-Object -ExpandProperty namespace -Unique

# Criar o Secret dummy em cada namespace
foreach ($ns in $namespaces) {
    Write-Host "`nCriando Secret dummy '$secretName' em: $ns"
    & $kubectl create secret generic $secretName `
        --from-file="dummy.json=$tempFile" `
        -n $ns `
        $kubeconfig `
        --dry-run=client -o yaml | & $kubectl apply -f - $kubeconfig
}

Remove-Item $tempFile
```

---

##  Verificar se os Secrets foram criados

```bash
kubectl get secrets --all-namespaces | grep dynatrace
```

---

## Impacto operacional

✅ **Seguro**: Nenhum Pod é reiniciado nem afetado por essa ação.  
✅ **Sem downtime**: O Kubernetes não remonta volumes nem interfere em containers em execução.  
✅ **Solução definitiva**: Os erros desaparecem da UI Dynatrace e o cluster fica mais limpo.

---

## Resultado esperado

- Erros de `MountVolume.SetUp failed` desaparecem da UI da Dynatrace.
- Nenhuma aplicação é impactada.
- Ambiente mais limpo, silencioso e compatível com futuras integrações.

---

## Requisitos

- `kubectl` configurado e com acesso ao cluster
- PowerShell (ambiente Windows)
- Scripts executados com permissão de criação de Secrets nos namespaces relevantes
