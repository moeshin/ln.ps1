
<#
ln -s -v -r a test
'test/a' -> '../a'

ln -s -v -r a /root/test
'/root/test/a' -> '../../www/a'
#>

$dir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($args[1].Replace('/', '\'))
$tagert = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($args[0].Replace('/', '\'))

$dir
$tagert


$a1 = $dir.split('\')
$a2 = $tagert.split('\')

$len1 = $a1.Count
$len2 = $a2.Count
if ($len1 -lt $len2) {
    $len = $len1
} else {
    $len = $len2
}

$path = ''
for ($i = 0; $i -lt $len; ++$i) {
    if ($a1[$i] -ne $a2[$i]) {
        $a = $a1[$i..$len1]
        $a -join '\'
        $a = $a2[$i..$len2]
        $a -join '\'
        break
    }
}


#Cannot find relative path on different disk