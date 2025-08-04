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

# Cria o Secret manualmente em cada namespace
foreach ($ns in $namespaces) {
    Write-Host "`nCriando Secret corretamente no namespace: $ns"
    & $kubectl create secret generic $secretName `
        --from-file="enrichment.json=$jsonPath" `
        -n $ns `
        $kubeconfig `
        --dry-run=client -o yaml | & $kubectl apply -f - $kubeconfig
}
