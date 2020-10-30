# GenerateTestScript

A tool to write FHIR TestScript instances that are more readable, better maintainable and can leverage reusable building blocks.

The approach is to use a custom dialect to enhance the FHIR TestScript syntax with a custom dialect, which is transformed using XSL to a regular FHIR TestScript. The custom dialect may be mixed with normal FHIR TestScript syntax at will. The transformation also takes care of adding the boilerplate stuff: url, date, publisher, contact, origin and destination.

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

It is possible to pass parameters to included components, using the `nts:with-parameter` element. The syntax is:

```xml
<nts:include value="..">
    <nts:with-parameter name="param1" value="...">
    <nts:with-parameter name="param2" value="...">
    ...
</nts:include>
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

It is also possible to recursively pass along parameters to other includes, simply by using the `{$...}` expansion in the `value` attribute of the next `<nts:with-parameter ...>` element.

If you use a parameter in a component without passing it from the caller or without specifying a default value, an error will be thrown.

### Fixtures, profiles and rules

For fixtures, profiles and rules, custom elements have been made that are a bit more concise than their FHIR equivalents.
  
Fixtures and rules can be defined using:

```xml
<nts:fixture id=".." href=".."/>
<nts:rule id=".." href=".."/>
```

`href` is considered to be relative to a predefined fixtures folder. It defaults to the "_reference" folder directly beneath the project-folder. See the section on building to set an alternate location. All fixtures and rules in the "_reference"-folder are copied to the output folder.

Profiles may be defined using:

```xml
<nts:profile id=".." value=".."/>
```

### Patient token and date T

There are two special elements for use cases that are common across Nictiz test scripts.

The first one for including the patient authorization token in the TestScript:

```xml
<nts:patientTokenFixture href="..">
```

The `href` attribute should point to the `Patient` instance containing the token, as is commonly done with the Nictiz test scripts, placed in the "_reference"-folder. The `nts:scenario` attribute on the TestScript root determines how this tag is expanded:

* for "server", a variable will be created which the test script executor can set, defaulting to the value from the fixture.
* for "client", the fixture will be included and a variable called "patient-token-id" will be created that reads the value from the fixture

The second element is to indicate that the "date T" variable should be defined for the testscript:

```xml
<nts:includeDateT value="yes|no">
```

If this element is present, and `value` is absent or set to "yes", a variable for setting date T will be included in the TestScript.

### Scenario: server (xis) or client (phr)

There may be differences for xis and phr scenarios in how a TestScript is transformed. The scenario must therefore be indicated using the following attribute on the `TestScript` root:

```xml
nts:scenario="server|client"
```

## Running the transformation

The transformation is called by the ANT build in `ant/build.xml`. For more information on the location of the inputs and outputs, see [the readme in the TestScripts repository](https://github.com/Nictiz/Nictiz-STU3-testscripts/blob/master/Generate/README.md).

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
- build.xml              : A file that imports the build script from this repository
- src/                   : The dir containing the NTS files, components and fixtures, orderded in project folders.  
    - common-asserts/    : The common components across all projects.
    - Project1/          : A project dir
        - InputFolder1/  : One or more dirs containg NTS files. _Warning_: all folder names starting with an underscore are ignored, while all other folders are included!
        - \_components/  : The components specific for that project
        - \_reference/   : The fixtures and rules for that project. This folder is copied verbatim to the output folder. 
- build/                 : The dir where the output will be placed (you probably want to add this to `.gitignore`)
- lib/                   : The dir where build tools should be placed (you probably want to add this to `.gitignore`)
    - ant-dependencies/  : The dir where the dependencies for ANT will be placed

By default, the script will ask you for one of the project dirs inside the `src/` dir and place the output in a folder with the project name in the `build/` dir. See below for the parameters to override this behavior. 

### Build script parameters

The build script recognizes several parameters:
- `-Dproject=<ProjectFolderName>`: Use this project folder instead of asking for it.
- `-Dbuild.dir=path/to/output/base`: Location to use instead of `build/`. Should be an absolute or relative path, compared to `build.xml`. The output will be placed in a folder with the same name as the project folder within this directory. _Warning_: existing content in this project output folder will be removed. Use with caution!
- `-Dreference.dir=/path/to/project/fixtures`: The (base) location for the fixtures for this project. Should be an absolute or relative location, compared to `build.xml`.
- `-Dcommoncomponents.dir=/path/to/common/components`: An alternative location for common NTS components. Should be an absolute or relative path, compared to `build.xml`.
- `-Dcomponents.dir=/path/to/project/components`: An alternative location for project specific NTS components. Should be an absolute or relative path, compared to `build.xml`.

## Schematron

A schematron is available that can be used to check both the input TestScript files and the component files. It is reasonably complete and covers everything on the root level of the input files.

It can be found at `schematron/NictizTestScript.sch` relative to this README.

## Output logging

Because of the verbosity of the ANT build, the logging level is set to 1 (warning) and Saxon is set to not try to recover. When more verbose output is wanted, the logging level can be changed by setting the `-DoutputLevel=` parameter on the ANT build.

## Changelog

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