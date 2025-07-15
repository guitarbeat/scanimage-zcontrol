# services

Contains standalone “business-logic” modules with zero GUI code. Each service:
- Lives in its own file
- Has a clear public API
- Never calls back into controllers or views

## Current modules
- **MetricsPlotService.m** – plotting abstraction  
- **ScanControlService.m** – wrap Thorlabs/ScanImage calls  
- **ConfigLoaderService.m** – load/save app settings  

## How to add a new service
1. Create `MyNewService.m` in this folder  
2. Follow the `getInstance()`, `initialize()`, `performAction()` pattern  
3. Write unit tests that mock everything outside this folder  

That structure and documentation style will keep each layer focused, make testing easy, and make newcomers’ lives a lot simpler. 