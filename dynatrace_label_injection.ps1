# Caminho do kubectl e do kubeconfig
$kubectl = ".\kubectl.exe"
$kubeconfig = "--kubeconfig=.\kubeconfig-homolog.yaml"

# Lista de namespaces do sistema a ignorar
$excludedNamespaces = @(
    "kube-system", "kube-public", "kube-node-lease",
    "cattle-system", "cattle-monitoring-system",
    "cattle-fleet-system", "cattle-impersonation-system",
    "calico-system", "tigera-operator",
    "longhorn-system", "cert-manager",
    "local-path-storage", "system-upgrade",
    "default"
)

# Obter todos os namespaces
$namespaces = & $kubectl $kubeconfig get ns -o jsonpath="{.items[*].metadata.name}" | Out-String
$namespaces = $namespaces.Trim().Split()

foreach ($ns in $namespaces) {
    if ($excludedNamespaces -notcontains $ns) {
        Write-Host "Aplicando label em namespace: $ns"
        & $kubectl $kubeconfig label ns $ns dynatrace.com/inject=true --overwrite
    } else {
        Write-Host "Ignorando namespace de sistema: $ns"
    }
}
