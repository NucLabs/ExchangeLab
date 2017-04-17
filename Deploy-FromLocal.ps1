pushd C:\Users\GertJanKraaijeveld\Source\Repos\ExchangeLab
$ResourceGroupName = 'ExLab'
$TemplateFile = 'azuredeploy.json'
$TemplateParametersFile = 'azuredeploy.parameters.local.json'
if ((Get-AzureRmResourceGroup $ResourceGroupName -ErrorAction SilentlyContinue).Count -eq 0){
  New-AzureRmResourceGroup -Name $ResourceGroupName -Location 'West Europe'
}

New-AzureRmResourceGroupDeployment -Name ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
                                   -ResourceGroupName $ResourceGroupName `
                                   -TemplateFile $TemplateFile `
                                   -TemplateParameterFile $TemplateParametersFile `
                                   -Force -Verbose -Mode Incremental
popd