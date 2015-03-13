

$NEWLINE = "`n"


Write-Host "Creating VM in Azure...this will take sometime."
vagrant up --provider=azure


Write-Host "VM Created...system is now generating scripts to provision them."
invoke-expression -Command .\ScriptGen.ps1


Write-Host $NEWLINE + "Task completed."