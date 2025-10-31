# Conformancelab property file generator

On the Conformancelab test platform, a property file in JSON format should be added to TestScript folders with data about these scripts. This tool is meant to generate these property files for all folders and subfolders based on folder structure conventions and information in the root folder of an NTS project. This mechanisms re-uses some of the properties set for the other tools in this repo.

| Conformancelab property | input                                                    | required? | notes                                                             | 
| ----------------------- | -------------------------------------------------------- | --------- | ----------------------------------------------------------------- |
| `fhirVersion`           | ANT property `fhir.version`                              | x         | Must be either "STU3" or "R4". Also used in other build steps.    |
| `goal`                  | ANT `goal` property, or root folder name                 |           |                                                                   |
| `informationStandard`   | ANT property `informationStandard`                       | x         |                                                                   |
| `usecase`               | ANT property `usecase`                                   | x         |                                                                   |
| `category`              | first subfolder which is not role                        |           |                                                                   |
| `subcategory`           | second subfolder which is not role                       |           |                                                                   |
| `role`                  |                                                          | x         |                                                                   |
| - `name`                | subfolder which matches entry in ANT property `roles`    | x         | `roles` is a comma separated list. See also `variant`             |
| - `description`         | ANT property `role.description.`_role_                   | x         |                                                                   |
| `variant`               |                                                          |           |                                                                   |
| - `name`                | Addition to `role` in the folder name                    |           | A variant will be emitted of the role folder contains an addition |
| - `description`         | ANT property `target.description`._target_               | (x)       | e.g. `target.description.XIS-Server-Nictiz-only = For Nictiz only |
| `adminOnly`             | ANT property `targets.adminOnly`                         | (x)       | Either "true" or "false"                                          |
| `fhirPackage`           |                                                          |           |                                                                   |
| - `name`                | ANT property `packages`                                  |           | This is a comma separated list of package canonicals              |
| - `version`             | ANT property `package.`_canonical_                       |           | e.g. `package.nictiz.stu3.zib2017 = 2.2.3`                        |
| `serverAlias`           | ANT property `server`, or                                | (x)       | One of these must be provided                                     |
|                         | match on ANT property `server.`_usecase_`.`_fhirVersion_ | (x)       | One of these must be provided                                     |

## Properties to set directly
As can be seen above, the following properties must be set in the `build.properties` files directly:

* `fhir.version`
* `informationStandard`
* `usecase`
* `packages`

## Goal
The `goal` parameter in the Conformancelab property file defines the goal the set of TestScripts is used for. At the time of writing, there can be two goals: testing and certification, or "Test" and "Cert". An important assumption about the folder organization of NTS projects is that everything for a goal is organized in one folder, and that this folder is the root of the NTS project.

So usually the `goal` property is set to the root folder name of the NTS project. If needed, it can be overridden using the `goal` ANT property.

## Role, category and subcategory
Conformancelab needs to know who the scripts are for. This is defined by the `role` property. In NTS projects, the scripts for a certain role are organized using folders within the root folder, e.g. "XIS-Server", "Sending-System", etc.

However, it is too naive to just use the folder name of the first subfolder as the `role` name, as there may be a need to add additional levels of subfolders to organize the TestScripts. These subfolders may be defined above and beneath the subfolder defining the role.

To solve this, the NTS property `roles` can be set to a comma-separated list of recognized role names within the NTS project. If the name of a subfolder in the folder hierarchy on the NTS input[^1] matches one of these entries, it's used as the `role`.

The other subfolders in the folder hierarchy, when present, are used as the `category` and `subcategory` properties in the Conformancelab property file.

To provide a description for a role, the `role.description.`_role_ ANT property is used.

## Variants / additional targets
"Variants" in Conformancelab parlance are what NTS calls "Additional targets". Additional targets are defined on roles and result in a subfolder name called `[role]-[target]`. If this tool encounters a subfolder which follows this pattern, it will set the `variant.name` parameter for the resulting property file(s).

To provide a description, set the ANT property `target.description.`_target_. If not set, this defaults to `role.description`.

## Fhir packages
For profile validation, Conformancelab needs to know which FHIR packages to use. This is done using the ANT property `packages`, which is a comma separated list of package canonicals.

However, for each package canonical, a version must be provided as well. This is done per package, using an ANT property called `package.`_package canonical_ set to the version to use.

## Server alias
Conformancelab needs to know which test server to use. This can be set directly using the ANT property `server`, which should be set to the _name_ of the server defined in the Conformancelab platform. However, it is more convenient to define default servers per usecase and FHIR version. This can by setting an ANT property called server.`_usecase_`.`_fhirVersion_.

[^1]: This is actually a lie. Property files are based on the _output_ folder structure, not the NTS _input_, so if there are additional targets, the subfolder name doesn't match what's in `roles`, so the tooling compares just the start of the folder name. But hey, it's complex enough as it is.

## Overrides
If the property values generated as described above need to be overridden, a file named `src-properties.json` can be placed in the NTS source directory. This file is copied to the output directory and renamed to `properties.json` during the 'generate' phase of the build.

If present, the contents of this file will be used to override the default, generated property values. This mainly allows for more control over `variant`s without relying on folder names, but also allows to, for example, set a custom `category` or `subcategory` name not based on folder names.

Overriding the `fhirPackage` nd `serverAlias` properties is not supported.