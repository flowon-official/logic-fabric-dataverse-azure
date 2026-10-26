# Notice

This repository is licensed under the MIT License (see [LICENSE](LICENSE)).

Parts of it are derived from [Azure-Samples/azmcp-obo-template](https://github.com/Azure-Samples/azmcp-obo-template),
Copyright (c) Microsoft Corporation, also licensed under the MIT License. Files containing derived
work say so in their header. They are:

- `foundry/azure.yaml`, `foundry/infra/main.bicep`, `foundry/infra/main.parameters.json`
- `conductor/azure.yaml`, `conductor/infra/main.bicep`, `conductor/infra/main.parameters.json`
- `modules/container-app.bicep`
- `modules/container-apps-environment.bicep`
- `modules/entra-agent-app.bicep`
- `modules/entra-agent-grant-permissions.bicep`
- `modules/entra-client-app.bicep`
- `modules/entra-server-app.bicep`
- `modules/monitoring.bicep`

Modifications and all other files are Copyright (c) 2026 Flowon Corp.

The templates reference [Azure Verified Modules](https://aka.ms/avm) from the public Bicep registry
(MIT License, Copyright (c) Microsoft Corporation). Those modules are downloaded at build time and
are not part of this repository.
