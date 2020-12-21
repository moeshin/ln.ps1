
<#
ln -s -v -r a test
'test/a' -> '../a'

ln -s -v -r a /root/test
'/root/test/a' -> '../../www/a'
#>

function getAbsolutePath($path) {
    return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($path.Replace('/', '\'))
}

function splitPath($path) {
    return $path.split('\', [StringSplitOptions]::RemoveEmptyEntries)
}

$dir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($args[0].Replace('/', '\'))
$tagert = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($args[1].Replace('/', '\'))

function getRelativePath($dir, $target) {
    $dir = getAbsolutePath($dir)
    $target = getAbsolutePath($target)
    $a1 = splitPath($dir)
    $a2 = splitPath($target)
    
    $len1 = $a1.Count
    $len2 = $a2.Count
    $len = if ($len1 -lt $len2) {$len1} else {$len2}

    $path = ''
    for ($i = 0; $i -lt $len; ++$i) {
        if ($a1[$i] -ne $a2[$i]) {
            if ($i -eq 0) {
#                "Cannot find relative path on different disk"
#                return $target
            }
        $n = $len1 - $i - 1
        if ($n -ge 0)  {
            $path += '..\' * $n
        }
        $path += $a2[$i..$len2] -join '\'
        
        return $path
    }
}

"PATH: $path"

}


