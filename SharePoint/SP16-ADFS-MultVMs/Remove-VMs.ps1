Import-Module Azure -ErrorAction SilentlyContinue
$azurecontext = Get-AzureRmContext -ErrorAction SilentlyContinue
if ($azurecontext -eq $null) {
    Login-AzureRmAccount
    $azurecontext = Get-AzureRmContext -ErrorAction SilentlyContinue
}
$subscriptionId = $azurecontext.Subscription.SubscriptionId
$resourceGroupLocation = 'westeurope'
$resourceGroupName = 'YD-SP16ADFS-2VM'
$resourceGroupName = 'xxYD-SP16ADFS-2VM'
$StorageAccountName = "xydsp16adfs2vmst"
$blobStorageContainer = "vhds"
$vmsToDelete = @("SP", "SQL", "DC")
$vmsToDelete = @("SP", "SQL")
$vmsToDelete = @("FE", "SP", "SQL")
$vmsToDelete = @("FE")
Set-AzureRmCurrentStorageAccount -ResourceGroupName $resourceGroupName -StorageAccountName $StorageAccountName 
Get-AzureRmContext

### DELETE SEQUENTIAL
ForEach ($vmToDelete in $vmsToDelete) {
#$vmsToDelete| Foreach-Object -Process {
    #$vmToDelete = $_
    $disksNames = @()
    $vm = Get-AzureRmVM -ResourceGroupName $resourceGroupName -Name $vmToDelete
    $disksNames+=$vm.StorageProfile.OsDisk.Name
    $vm.StorageProfile.DataDisks| %{$disksNames+=$_.Name}
    
    Write-Output "Removing VM $vmToDelete..."
    Remove-AzureRmVM -ResourceGroupName $resourceGroupName -Name $vmToDelete -Force

    #Get-AzureStorageContainer -Name $blobStorageContainer | Get-AzureStorageBlob | ft Name
    $disksNames| Foreach-Object -Process {
        Write-Output "Removing disk $_..."
        Remove-AzureStorageBlob -Container $blobStorageContainer -Blob $_".vhd"
    }
    Write-Output "VM $vmToDelete deleted."
}

### DELETE PARALLEL (NOT WORKING)
{
ForEach ($vmToDelete in $vmsToDelete) {
    $scriptBlockDeleteVM = {
        Param
        (
        #[Microsoft.Azure.Commands.Profile.Models.PSAzureContext] $azurecontext,
        [String] $vmToDelete,
        [String] $resourceGroupName,
        [String] $blobStorageContainer,
        [String] $StorageAccountName
        )
        $azurecontext = Get-AzureRmContext -ErrorAction SilentlyContinue
        #Set-AzureRmCurrentStorageAccount -ResourceGroupName $resourceGroupName -StorageAccountName $StorageAccountName 
        $disksNames = @()
        $vm = Get-AzureRmVM -ResourceGroupName $resourceGroupName -Name $vmToDelete
        $disksNames+=$vm.StorageProfile.OsDisk.Name
        $vm.StorageProfile.DataDisks| %{$disksNames+=$_.Name}
    
        Write-Output "Removing VM $vmToDelete..."
        Remove-AzureRmVM -ResourceGroupName $resourceGroupName -Name $vmToDelete -Force

        #Get-AzureStorageContainer -Name $blobStorageContainer | Get-AzureStorageBlob | ft Name
        $disksNames| Foreach-Object -Process {
            Write-Output "Removing disk $_..."
            Remove-AzureStorageBlob -Container $blobStorageContainer -Blob $_".vhd"
        }
        Write-Output "VM $vmToDelete deleted."
    }
    Start-Job -scriptblock $scriptBlockDeleteVM -ArgumentList $vmToDelete, $resourceGroupName, $blobStorageContainer, $StorageAccountName

}
Get-Job | Wait-Job
Get-Job | Receive-Job 
}

Write-Output "Finished."
