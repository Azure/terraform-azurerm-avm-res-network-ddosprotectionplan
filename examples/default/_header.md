# Default example

This deploys the module in its simplest form.

> [!WARNING]
> A DDoS Network Protection plan carries a flat monthly charge, prorated by the hour, from the moment the plan exists - whether or not any virtual network is associated with it. Run this example only when you need it and `terraform destroy` as soon as you are done. See the [Azure DDoS Protection pricing page](https://azure.microsoft.com/pricing/details/ddos-protection/) for the current rate.

This example replaces the earlier `default-azurerm-v3` and `default-azurerm-v4` examples. Those existed only to prove the module worked against both major versions of the AzureRM provider; the module no longer uses that provider, so a single example is enough - and it halves the cost of a full example run.
