$Userprincipalname = "user@domain.com"

$mappedupn = ($Userprincipalname.Split('@')[0]).Replace('.','-')

$mappedsecretname = "sec" + "-" + "$($mappedupn)" + "-" + "pwd" + "-" + "companyname"

$mappedsecretname
