# GenerateTestScript

A tool to write FHIR TestScript instances that are more readable, better maintainable and can leverage reusable building blocks.

The approach is to use a custom dialect to enhance the FHIR TestScript syntax with a custom dialect, which is transformed using XSL to a regular FHIR TestScript. The custom dialect may be mixed with normal FHIR TestScript syntax at will.

The transformation also takes care of adding the boilerplate stuff like url, date, publisher, contact, origin and destination.

Note that the script is specifically aimed at use within Nictiz:

* Publisher etc. is set to Nictiz.
* The TestScript is in R5 format for use at the Conformancelab test platform.
* Extensions needed for the Conformancelab test platform are added. 

## Custom dialect

### Namespace

All the custom elements use the following namespace:

```xml
xmlns:nts="http://nictiz.nl/xsl/testscript"
```

### Recursive inclusion of components

One of the core principles in this method is that it should be possible to easily include other files as reusable components. Such a component includes everything that is needed for performing part of a test: the actions, the asserts, but also variables, fixtures, rules _and_ possibly other components.

To define a component, simply create an .xml file with the necessary content enclosed in the following tags:

```xml
<nts:component xmlns="http://hl7.org/fhir" xmlns:nts="http://nictiz.nl/xsl/testscript">
    ...
</nts:component>
```

Normally, these components are collected in a subdirectory called "_components" in the project folder. Additionally, the subdirectory "common-components" in the src-folder contains building blocks that can be used across *all* projects. See the section on building to override these locations.

A building block can then be included using:

```xml
<nts:include value=".." scope="project|common"/>
```

Where `value` should be the name of the file to include (the ".xml" part may be omitted). The `scope` attribute defaults to "project" if it is ommitted.

Alternatively, the following form may be used:

```xml
<nts:include href="..."/>
```

to refer to a file directly, relative from the input file.

*Note*: the transformation will take care of putting all included variables, fixtures, etc. in the right place in the resulting TestScript. If different components define the same variable, fixture, etc., it will be deduplicated. If they define a different variable, fixture, etc. with the same id, an error will be thrown.

#### Passing parameters

It is possible to pass parameters to included components, using either the `nts:with-parameter` element or attributes. The syntax is:

```xml
<nts:include value="..">
    <nts:with-parameter name="param1" value="...">
    <nts:with-parameter name="param2" value="...">
    ...
</nts:include>
```

or

```xml
<nts:include value=".." param1="..." param2="..." />
```

In the corresponding component, the variable can be used with the XSL syntax for variables:

```xml
<nts:component ...>
    <variable>
        <name value="foo"/>
        <defaultValue value="{$param1}"/>
    </variable>
</nts:component>
```

#### Default values

In a component, a default value for a variable can be added using the `nts:parameter` element. This way, a component can be included without specifying a parameter value, while the parameter value can be overridden by specifying an `nts:with-parameter` element while including. 

Compare the following two examples (the first wil result in a value of 'foo' for `{$param1}`, the second will result in a value of 'bar' for `{$param1}`):

```xml
<nts:include value="..">
    <nts:with-parameter name="param1" value="foo">
</nts:include>    
<nts:component ...>
    <nts:parameter name="param1" value="bar"/>    
    <variable>
        <name value="foo"/>
        <defaultValue value="{$param1}"/>
    </variable>
</nts:component>

<nts:include value=".."/> 
<nts:component ...>
    <nts:parameter name="param1" value="bar"/>    
    <variable>
        <name value="foo"/>
        <defaultValue value="{$param1}"/>
    </variable>
</nts:component>    
```

Parameters passed to a component are globally available in the entire chain of recursive includes from there on. So if you pass parameter `foo` when including component 1, and this component subsequently includes component 2, `foo` is available to both components. It is also possible to expand parameters when recursively including the next component (i.e. a component that gets passed `param` may use `<nts:with-parameter name="param2" value="{$param1}">` when including other components).

If you use a parameter in a component without passing it from the caller or without specifying a default value, an error will be thrown.

#### Conditional processing based on parameters

It is possible to activate or suppress elements in included files based on the passing of a parameter using the `nts:ifset` and `nts:ifnotset` attributes. For example:

```xml
<nts:component ...>
    <description nts:ifset="description" value="{$description}"/>
    <description nts:ifnotset="description" value="Test to serve {$resource} resources."/>    
</nts:component>
```

If the `description` parameter is omitted when including this component, the latter of the two `<description .../>` elements will be used to create an autogenerated description string. Otherwise, the first element is used to write out the given description in the output.

### Defining fixtures, profiles and rules

Fixtures, profiles and rules all have te be declared in a TestScript before they can be used in a test. Custom elements have been made that are a bit more concise than their FHIR equivalents.
  
Fixtures and rules may be declared using:

```xml
<nts:fixture id=".." href=".."/>
<nts:rule id=".." href=".."/>
```

`href` is considered to be relative to a predefined fixtures folder. It defaults to the "_reference" folder directly beneath the project-folder. See the section on building to set an alternate location. All fixtures and rules in the "_reference"-folder are copied to the output folder.

Profiles may be declared using:

```xml
<nts:profile id=".." value=".."/>
```

#### Fixtures

Within the `@href` attribute of `nts:fixture`, the parameter `{$_FORMAT}` can be used to automatically output the format (either `xml` or `json`) the fixture is expected to be in.

During building, a check will be done on the existence of fixtures that are directly referenced from the TestScripts. It is possible to make an exception for the special situation where a fixture is declared in JSON format but only exists in XML format by setting the `convert.to.json.file` build parameter to the path of a readable file. All the XML version of JSON fixtures will be written to this file, so they can be converted later on. A separate script for this is available in the folder "convertXmlToJson".

A LoadResources script is generated for all fixtures in the "_reference"-folder. See the section on building on how to exclude files and/or folders from being added the LoadResources script. Usually, fixtures that are only used for sending need to be excluded from the LoadResources script.

##### Including fixtures in other fixtures

With a fixture, the inclusion of another fixtures is declared using:

```xml
<nts:includeFixture href="..."/>
```

`href` is considered to be relative to a predefined fixtures folder.

This feature can, for example, be used to include resources that are defined and maintained independently in Bundle-fixtures:
```xml
<entry>
    <fullUrl value="urn:uuid:4637e949-e4f9-43ad-bbb4-d28a120f101d"/>
    <resource>
        <nts:includeFixture href="resources-send-receive/selfmeasurements-send-respiration-1.xml"/>
    </resource>
    <request>
        <method value="POST"/>
        <url value="Observation"/>
    </request>
</entry>
```
In this use case, references in the included fixtures are checked and rewritten where necessary.

#### Using rules

Once a rule is declared, it may be used in an `<assert>` using the same tag with only the `id` attribute set. Optional parameters to the rule are passed as attributes or using the `<nts:with-parameter>` tag, similar to how it is done with `<nts:include/>`: 

```xml
<nts:rule id=".."
  param1="value1"
  param2="value2" />
```

is equivalent to:

```xml
<nts:rule id="..">
  <nts:with-parameter name="param1" value="value1"/>
  <nts:with-parameter name="param2" value="value2"/>  
</nts:rule>
```

It is also possible implicitly declare the rule when it is used by adding the `href` attribute here, e.g.:
```xml
<assert>
  ..
  <nts:rule id=".." href=".."
    param1="value1"
    param2="value2" />
  ..
</assert>  
```

Lastly, it is possible to use [rule outputs](https://touchstone.aegis.net/touchstone/userguide/html/testscript-authoring/rule-authoring/rule-outputs.html). This is done using a nested `<nts:output name="...">` tag. Optionally, the `type` and `contentType` attributes may be used in this element (see the Touchstone documentation for more information). Conveniently, the magic parameter `$_FORMAT` also works in the `contentType` attribute.

```xml
<assert>
  ..
  <nts:rule id="..">
    <nts:output name="outputName" type="document" contentType="$_FORMAT"/>
  </nts:rule>
</assert>
```

### Date T and authorization headers

There are special elements for two use cases that are common across Nictiz test scripts.

The first one is to indicate that the "date T" variable should be defined for the TestScript:

```xml
<nts:includeDateT value="yes|no">
```

If this element is present, and `value` is absent or set to "yes", a variable for setting date T will be included in the TestScript.

The second one deals with the authorization header for defining the patient context in the TestScript. The assumption here is that the (static) content of an `Authorization` header associated with a specific Patient resource `.id` is defined in a JSON file with the following syntax:
```json
{
    "accessToken": "Bearer ...",
    "resourceId": "[resource.id of Patient resource]",
}
```

This file should be passed as the `tokens.json` parameter to the build script. The token can then be imported into a TestScript using:

```xml
<nts:authToken patientResourceId="[resource.id of Patient resource]" {id="[patient-token-id]"}/>
```

This sets an NTS parameter with the specified `id`, which can then be used throughout the NTS file. `id` is usually omitted, in which case it defaults to "patient-token-id". 

For example, if you included a token with id "patient-token-id", you can use it to define the Authorization header with: 
```xml
<requestHeader>
  <field value="Authorization"/>
  <value value="{$patient-token}"/>  
</requestHeader>
```

The output depends on `nts:scenario`. For client scripts, the content of the access token will be hardcoded in the TestScript output. For server scripts, a TestScript variable will be defined that defaults to the access token, but which can be overruled by the tester. The NTS variable will be translated to this TestScript variable.

There is actually a second (outdated) mechanism to import authorization tokens:

```xml
<nts:patientTokenFixture href="..">
```

The `href` attribute should point to a `Patient` instance containing the content of the authorization header as its `.id`, placed in the "_reference"-folder and with a file name ending in `-token.xml`. This will always result in definig the TestScript variable `patient-token-id`, for both client and server scripts.

### Scenario: server (xis) or client (phr)

There may be differences for xis and phr scenarios in how a TestScript is transformed. The scenario must therefore be indicated using the following attribute on the `TestScript` root:

```xml
nts:scenario="server|client"
```

When the scenario is set to 'server', the magic variable `{$_FORMAT}` becomes available to `nts:fixture` and to `.operation.contentType`, which will result in the string 'xml' when generating the xml instance and in 'json' when generating the json instance.

### Content asserts

It is possible (to a certain degree) to generate asserts for the contents of the resources sent or served by the system under test. To generate these asserts, a fixture in XML format must be provided with all the content that (minimally) needs to be present in the corresponding resource produced by the system under test. It can be included using the following syntax:

```xml
<nts:contentAsserts href="[relative/path/to/fixture"/>
```

Just as with the `<nts:fixture>` tag, `href` is considered to be relative to a predefined fixtures folder.

*Please note*: fixtures are usually needed for one scenario of the two scenarios. Usually (for scenarios where the client retrieves data from the server), they are needed for TestScripts aimed at testing client systems. The test simulator mimics the server in this case and needs the fixtures to serve to the client, while the corresponding TestScript for the server does not need fixtures as the FHIR data is produced by the server. For content asserts, this situation is reversed: it is the TestScript for the server where content asserts are needed. It is logical to use the same fixture directly in the client TestScript and for the content asserts in the server TestScript, but one should be aware of this dual use and make sure that the content of these fixtures is suitable for both.

When the request or response body to check contains a Bundle instead of a single resource (e.g. in case of a search), the fixture needs to be matched to one of these resources within the Bundle. This cannot be done automatically, the tooling has to be told what to look for. This can be done in two ways. 

The easiest is to use one or more _discriminators_. These are simple FHIRPath expressions that contain just a selector for a unique property, and they are wrapped by the tooling in the expression `Bundle.resource.ofType( [resource type of fixture] ).where( [discriminator] )` to extract the proper resource. A discriminator can be set using either the `discriminator` attribute or one or more embedded `<nts:discriminator>` tags (multiple discriminators are combined using a logical AND), e.g.

```xml
<nts:contentAsserts href="..." discriminator="code.where(coding.code = '30350-3') and value.ofType(Quantity).where(value = '5.9')"/>
```

or

```xml
<nts:contentAsserts href="...">
    <nts:discriminator>code.where(coding.code = '30350-3')</nts:discriminator>
    <nts:discriminator>value.ofType(Quantity).where(value = '5.9')</nts:discriminator>
</nts:contentAsserts>
```

In the case discriminators are too limited, a _selector_ can be defined as a full FHIRPath expression to select the relevant resource. This is done using the `selector` attribute, e.g.

```xml
<nts:contentAsserts href="..."
    selector="iif(Bundle.entry.resource.ofType(Immunization)[0].date &lt; Bundle.entry.resource.ofType(Immunization)[1].date, Bundle.entry.resource.ofType(Immunization)[0], Bundle.entry.resource.ofType(Immunization)[1])"/>
```

Since FHIRPath expressions are not too easy to read, a description of the the discriminator of selector must be provided, using the `description` attribute. In will be used in the following sentence: "Response Bundle contains exactly 1 [fixture resource type] with properties: [description]".

Please note: the purpose of this description is to provide a human readable description of what is selected for. It should not be dumbed down to a level where it is not useful anymore to a technical person, but on the other hand it should not contain so many details that it becomes unreadable. E.g. "a blood pressure Observation" is too meager, but something like ".code is set to '85354-9'" provides the user with the information needed.

#### Limitations

Unfortunately, not all content can be checked automatically. Dates and times are problematic due to differences in precision, time zone handling, or simply because times cannot be explicitly set in the system under test. Text strings often differ slightly in casing and spacing. Display values of coded information is not required to match the fixture as multiple synonyms may be present.

The tooling handles data in the following way:
- _string_: existence only
- _date_, _dateTime_ and _instant_: existence only
- _code_: exact match
- _uri_:
  - in _Coding_, _Meta_ or _Quantity_: exact match
  - otherwise: existence only
- _canonical_:
  - in _Coding_, _Meta_ or _Quantity_: exact match
  - otherwise: not checked
- other simple data types:
  - in _Attachment_: existence only
  - otherwise: unsupported (a warning is raised when they are encountered)
- _Identifier_: existence of the same elements as in the fixture
- _References_: default expression to check for existence of `.reference` or `.identifier`, `.type` (for R4) and `.display`
- _Narrative_:
  - when `.type` is _extensions_ or _generated_: existence only
  - otherwise: not supported
- _Address_, _Annotation_, _BackboneElement_, _Element_, _CodeableConcept_, _Coding_, _ContactPoint_, _Dosage_, _Duration_, _HumanName_, _Meta_, _Period_, _Quantity_, _Range_, _Ratio_ and _Timing_: child elements are checked according to the list of primitive data types above
- extensions: a selector for the specified canonical url is created and the value is checked according to the data type above
- Other data types are not supported (a warning is raised when they are encountered)

#### Output

Each `<nts:contentAsserts>` tag results in an new `TestScript.test` section that only contains asserts, which operate on the body of the last performed operation (taking into account the scenario for which the TestScript is created). The first assert checks for the unique existence of the resource selected using the discriminator or selector. If this assert fails, the entire test is halted.

All other asserts perform the actual content checks. A numeric label is added to each assert in order that represents the path within the fixture, which should help with deeply nested data.

To aid with this setup, a `.requestId` or `.responseId` is always added to the `.operation`'s in the TestScript.

### Origins and destinations

The tooling will by default add one `origin` and one `destination`, both with `index` set to 1. The ConformanceLab extension to define if the origin/destination is the system under test is added and populated based on the scenario.

If needed, this behavior can be overruled with the following tags:

* `<nts:origin index="..." isSUT="[true|false]"/>`
* `<nts:destination index="..." isSUT="[true|false]"/>`

When these tags are used, no defaults are generated.
 
*Please note*: in version 2 of the tooling, the `nts:numOrigins` and `nts:numDestination` attributes on the `TestScript` root could be used. These have been deprecated, as these would not allow to specify which origin/destination is the system under test.

### Building different variants

It is possible to build different variants or _targets_ from the same source files that include different elements (these have to be defined using the `targets.additional` parameter during building, see the section on build script parameters further down this document on guidance). The `nts:in-targets` attribute can be used on elements to specify the targets where the element should end up in. If this attribute is absent, the element will be included in all targets. Mulitple targets may be separated by a space. The special target '#default' can be used for the default build.

For example, take the following snippet:

```xml
<assert>
   ...
</assert>   
<assert nts:in-targets="with-setup test">
   ...
</assert>
<assert nts:in-targets="#default">
   ...
</assert>
```

This specifies that:
* The first `assert` will be included in all targets.
* The second `assert` will be included in the targets 'with-setup' and 'test', but will not show up in the default build.
* The third `assert` will be included only in the default build (and thus not in 'with-setup' or 'test'). This construction can thus be used to _exclude_ elements from specific targets. 

### TouchStone stopTestOnFail extension
The TouchStone assert-stopTestOnFail extension is added to each assert with a default value of 'false' (e.g. the test continues running after a failed assertion). If you would like to override this value, add attribute `@nts:stopTestOnFail="true"` to `<assert>`.

```xml
<assert nts:stopTestOnFail="true">
    ...
</assert>
```

## Running the transformation

The transformation is called by the ANT build in `ant/build.xml`. For more information on the location of the inputs and outputs, see [the readme in the TestScripts repository](https://github.com/Nictiz/Nictiz-STU3-testscripts-src/blob/main/README.md).

## Building

There is an [Apache ANT](http://ant.apache.org/) based build file available (`ant/build.xml`) to facilitate building of NTS projects. The normal use of this build script is to keep it in the current folder structure and include/import it from another ANT build script, like:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project basedir="." name="generateTestScriptsForProject">

    <include file="path/to/this/build.xml" as="base"/>
    
    <target name="build" depends="base.build">
        ...
    </target>        
</project>
```

### Folder structure

For the project build file, a particular folder structure is expected:
```
- Project1/          : A project dir
  - build.properties : A file where parameters to the build script may be set (see below).
  - InputFolder1/    : One or more dirs containg NTS files. WARNING: all folder names starting with an underscore are ignored, while all other folders are included!
  - /_components/    : The components specific for that project - may be overridden using the components.dir parameter
  - /_reference/     : The fixtures and rules for that project. This folder is copied verbatim to the output folder. 
```

### Build script parameters

The following build script parameters are required:
- `input.dir=/path/to/projectdir`: Use this folder as the input. Should be an absolute or relative location, compared to `build.xml`.
- `output.dir=path/to/output/projectdir`: Location for the output of the build script. _Warning_: existing content in this project output folder will be removed.
- `commoncomponents.dir=/path/to/common/components`: The location for common NTS components. Should be an absolute or relative path, compared to `build.xml`.
- `lib.dir=/path/to/lib/dir`: The location to place dependency's needed for building the project. This dir should be added to `.gitignore`.

The following optional parameters may be used:
- `outputLevel=<number>`: Increase or decrease verbosity of the build script (default = 1).
- `components.dir=/path/to/project/components`: An alternative location for project specific NTS components. Should be an absolute or relative path, compared to `build.xml`.
- `reference.subdir`: The _name_ (not the path!) of the folder containing fixtures. Defaults to '_reference'. Could be used when an additional target uses a different reference folder.
- `loadresources.exclude`: a relative path to a folder containing the fixtures to be excluded or to specific filenames. Multiple entries can be comma separated. `*` is accepted as a wildcard.
  ```
  loadresources.exclude = _reference/resources/resources-specific
  ```
- `targets.additional`: additional variations of input folders (_targets_) that should be generated. An extra target is specified as the name of the folder that should be generated, which should be an existing folder with the target name appended using a dash. For example, if the project folder contains the folder `Cert`, an extra target named "with-setup" is defined using:
  ```
  targets.additional=Cert-with-setup
  ```
  The TestScript resources can use the `nts:in-targets` to define which element should be included in a target (see above). Multiple extra targets may be separated using comma's.
  Note: if there are subfolders in the folder on which an additional target is defined, each variant of the input folder will contain the full set of subfolders (but with slightly different content, of course).  
- `targets`: This parameter contains the default target '#default', to which the targets defined in `targets.additional` are added. Used when building the default target is unwanted.
- `version.addition`: a string that will be added verbatim to the value in the `TestScript.version` from the input file. If this element is absent, it will be populated with this value.
- `convert.to.json.file`: the path of a writable file where all referenced JSON fixtures are collected that don't exists, but for which an XML counterpart exists. This file can be used for the 'convertXmlToJson' script in this repo. If this parameter is not set, this situation will be treated like any other missing fixture and the build will fail.

### Building multiple projects

An additional buildscript is available (`ant/build-multiple.xml`) to build multiple projects, as long as each project has a `build.properties` file to set the parameters for a normal build using the procedure described above. To use this script, you need to include it in another script and set the following:

* A fileset with the `id` set to `input.files` should be defined with all the `build.properties` files that need to be built.
* The `basedir` property should point to the same basedir that the `build.properties` files in the project folders use.

## Schematron

A schematron is available that can be used to check both the input TestScript files and the component files. It is reasonably complete and covers everything on the root level of the input files.

It can be found at `schematron/NictizTestScript.sch` relative to this README.

## Output logging

Because of the verbosity of the ANT build, the logging level is set to 1 (warning) and Saxon is set to not try to recover. When more verbose output is wanted, the logging level can be changed by setting the `-DoutputLevel=` parameter on the ANT build.

## Changelog

### 3.0.0
- Major release aimed at working on the Conformancelab test platform by Interoplab:
  - TestScripts are now in FHIR R5
  - The necessary extensions for Conformancelab are added
  - `nts:numOrigins` and `nts:numDestinations` has been deprecated in favor an explicit the `nts:origin` and `nts:destination` notation.
  - A script has been added to generate Conformancelab properties files.

### 2.8.0
- Major internal rewrite to migrate functionality from ANT to XSLT, which is more powerful and maintainable. The functionality should be the same.

### 2.7.0
- Add support for rule outputs using the `<nts:output>` tag within `<nts:rule>`. WARNING: the `<nts:param>` tag for rules is renamed to `<nts:parameter>` as well!

### 2.5.1
- BUGFIX: Allow multiple Patient-resources to have the same token in the loadscript.

### 2.5.0
- Add the tag `<nts:authToken/>` to work with authorization tokens defined in a JSON file, as is expected for mock authentication on Touchstone. This supersedes the `<nts:patientTokenFixture/>` tag.

### 2.4.1
- Make the magic _FORMAT parameter available to nts:ifset

### 2.4.0
- Add an extra script to convert XML fixtures to JSON. This can be used separately or in conjunction with the NTS build script.

### 2.3.0
- Add the option to include fixtures in other fixtures, which are resolved during build. When used in batch/transation Bundles, references are checked and edited where neccessary.
- (Further) parametrize targets and reference directory to be able to overrule these properies in specific builds.
- KT-330: In LoadResources generation, the Bearer token relevant to the updateCreate of a Patient is added (instead of a static token).
- When too long, `TestScript.id` is restricted to the last 64 characters instead of the first to better warrant uniqueness.

### 2.2.0
- Add the option to generate multuple origins and targets.
- Fixed a bug where 'special characters' in a local path would lead to the LoadResources outputting this local path instead of a relative path.
- Allow for additional targets being defined at a lower level than the input folder.
- Fixed a bug where defining additional target led to multiple TestScripts having the same  `.id` and `.url`.

### 2.1.1
- Changed some CodeSystem uris from STU3 to their R4 counterpart.

### 2.1.0
- Allows the use of a `{$_FORMAT}` parameter to output the format (`xml` or `json`) in fixture referencing.

### 2.0.0
- The tooling now produces TestScript resources in FHIR R4 rather then STU3.


### 1.10.0
- An extra buildscript has been added (ant/build-multiple.xml) that allows you to build multiple projects, as long as they have a build.properties file that sets the parameters for building each project.
- Make the building of additional targets work when there are subdirs (HIT-21)
- For the centralizeLoadResources script, the subdirs parameters may now include spaces.

### 1.9.0
- FIX: still produce unix path if the input is already a unix path
- Fix for broken reference checking.
- FIX: Set priority on filtering templates to ensure that there are no multiple matches
- Fixed a broken url to README
- Fix the broken components.dir parameter

### 1.8.0
- Add the option to include or exclude elements in components when a parameter is set or omitted.

### 1.7.0
- Expansion of parameters in subsequent parameter calls (and make clear that parameters are globally available across the inclusion chain).
- Use attributes on nts:include elements as an alternative to nts:with-parameter.

### 1.6.0
- Add tooling to copy all loadresources script to a central location. This makes it easier to manage the permissions of the loadresources script when deployed to Touchstone.

### 1.5.0
- Remove the date from TestScripts (MM-1976)
- Add the option to pass a version addition to the build script (MM-1976)
- Don't strip out unknown input elements in the NTS source file

### 1.4.0
- Add the option to build different variants of a folder that include/exclude parts in the output (HIT-15). 

### 1.3.0
- Remove the assumptions on folder structure and instead use explicit parameters to define input dir, output dir, common components dir and lib dir (HIT-12).

### 1.2.1
- Fixed a bug where a comma separated list in `loadresources.exclude` caused the process to crash.
- Fixed a bug were the process would crash if `loadresources.exclude` is not set.
- Ids of fixtures that are added to LoadResources are validated.
- Added support for asterisk wildcards in `loadresources.exclude`.
- A LoadResources script is not generated if there are no fixtures to generate it from.

### 1.2.0
- A LoadResources script is now generated for a project
- TouchStone stopTestOnFail extension is added to each assert

### 1.1.4
- Fixed a bug where an attribute in a non nts-namespace (for example `@xsi:*`) caused the process to crash.

### 1.1.3
- Fixed a bug where the `-Dtestscripttools.localdir` property did not work as expected. 

### 1.1.2
- Enabled `<nts:parameter>` within `<nts:component>` to be given an empty value.

### 1.1.1
- MM-1116 - Removed FHIR version from canonical.

### 1.1.0
- Restructuring and improving ANT build - enabling derived scripts, improving workflow. 

### 1.0.0
- First working version to build TestScripts from the NTS-format using ANT.
