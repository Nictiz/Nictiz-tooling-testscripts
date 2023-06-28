# ConvertXmlToJson

Java based tool to convert fixtures in XML format to JSON. This is done using the [HAPI FHIR library](https://hapifhir.io/).

A JDK version 11 or higher is required.

For more info on how to use the tool, please check `ant/build.xml`.

This tool can neatly be used together with the NTS build tool for autoconverting XML fixtures to JSON. To do so, pass the `convert.to.json.file` parameter to the NTS build tool as the path to a file where all XML fixtures can be collected that need to be converted to JSON. This parameter can then be passed to this build file.