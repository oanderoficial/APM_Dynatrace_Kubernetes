# Caminho do kubectl e do kubeconfig
$kubectl = ".\kubectl.exe"
$kubeconfig = "--kubeconfig=.\kubeconfig-homolog.yaml"

Write-Host "`n Iniciando remoção do Dynatrace..." -ForegroundColor Cyan

# 1. Remover todos os DynaKubes e ActiveGates
Write-Host "`n Removendo recursos DynaKube e ActiveGate..." -ForegroundColor Yellow
& $kubectl $kubeconfig delete dynakube --all -A
& $kubectl $kubeconfig delete activegate --all -A

# 2. Remover secrets relacionados a tokens
Write-Host "`n Removendo secrets com 'dynatrace' ou 'token' no nome..." -ForegroundColor Yellow
$secrets = & $kubectl $kubeconfig get secrets -n dynatrace -o name | Select-String 'token|dynatrace'
foreach ($secret in $secrets) {
    & $kubectl $kubeconfig delete $secret -n dynatrace
}

# 3. Remover releases Helm no namespace dynatrace
Write-Host "`n Removendo Helm releases no namespace dynatrace..." -ForegroundColor Yellow
$releases = & helm list -n dynatrace -o json | ConvertFrom-Json
foreach ($release in $releases) {
    $releaseName = $release.name
    Write-Host "→ Removendo release Helm: $releaseName"
    & helm uninstall $releaseName -n dynatrace
}

# 4. Remover CRDs relacionados ao Dynatrace
Write-Host "`n Removendo CRDs com 'dynatrace'..." -ForegroundColor Yellow
$crds = & $kubectl $kubeconfig get crd | Select-String 'dynatrace' | ForEach-Object { ($_ -split '\s+')[0] }
foreach ($crd in $crds) {
    & $kubectl $kubeconfig delete crd $crd
}

# 5. Remover namespace dynatrace
Write-Host "`n Removendo namespace dynatrace..." -ForegroundColor Yellow
& $kubectl $kubeconfig delete ns dynatrace

# 6. Remover labels Dynatrace dos namespaces
Write-Host "`n Limpando labels Dynatrace dos namespaces..." -ForegroundColor Yellow
$namespaces = & $kubectl $kubeconfig get ns --no-headers | ForEach-Object { ($_ -split '\s+')[0] }
foreach ($ns in $namespaces) {
    & $kubectl $kubeconfig label ns $ns dynatrace.com/injection- dynatrace.com/monitoring- --overwrite 2>$null
}

# 7. Verificação final
Write-Host "`n Verificação final de recursos residuais Dynatrace:" -ForegroundColor Cyan
& $kubectl $kubeconfig get all -A | Select-String "dynatrace|oneagent"

Write-Host "`n Remoção concluída!" -ForegroundColor Green
