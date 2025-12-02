
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0"
    xmlns="http://hl7.org/fhir"
    xmlns:f="http://hl7.org/fhir"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:fn="http://www.w3.org/2005/xpath-functions"
    xmlns:array="http://www.w3.org/2005/xpath-functions/array"
    xmlns:map="http://www.w3.org/2005/xpath-functions/map"
    xmlns:nts="http://nictiz.nl/xsl/testscript"
    exclude-result-prefixes="#all">
    <xsl:output method="xml" indent="yes"/>
    <xsl:strip-space elements="*"/>
    
    <!-- Directory containing NTS-files and therefore potentially a Conformancelab src-properties file -->
    <xsl:param name="inputDir" required="yes"/>

    <!-- The directory where the resulting Conformancelab proiperties file should be stored. -->
    <xsl:param name="outputDir" required="yes"/>
    
    <xsl:param name="fhirVersion" as="xs:string"/>
    
    <!-- The "goal" according to the Conformancelab spec. -->
    <xsl:param name="goal" as="xs:string"/>
    
    <!-- The "informationStandard" according to the Conformancelab spec. -->
    <xsl:param name="informationStandard" as="xs:string"/>
    
    <!-- The "usecase" according to the Conformancelab spec. -->
    <xsl:param name="usecase" as="xs:string"/>
        
    <!-- An NTS input file can nominate elements to only be included in specific named targets using the nts:only-in
         attribute. The "target.dir" parameter (which defaults to '#default' if no other target is specified) contains
         the full target directory defined in property 'targets.additional' (comma separated) in the build properties.
         For example: 'XIS-Server-Nictiz-intern' or 'MedicationData/Send-Nictiz-intern'. The actual target name used in
         an NTS-file is extracted from this. -->
    <xsl:param name="target.dir" select="'#default'"/>
    
    <xsl:include href="_ntsFolders.xsl"/>
    
    <xsl:template match="/" name="createPropertiesInTargetFolder">
        <xsl:variable name="ntsFolders" select="distinct-values(uri-collection(concat('file:///', translate($inputDir, '\', '/'), '?select=*.xml;recurse=yes')) ! resolve-uri('.', .)[not(contains(., '/_'))]) ! string()"/>
        
        <xsl:for-each select="$ntsFolders">
            <!-- Get all properties of this folder that are to be used later -->
            <xsl:variable name="nts.file.dir.properties" as="map(*)">
                <xsl:call-template name="ntsDirProperties">
                    <xsl:with-param name="ntsDir" select="."/>
                </xsl:call-template>
            </xsl:variable>
            
            <!-- Generate output if:
                 - target is #default OR
                 - if target contains reldir (for example, target is 'XIS-Server-Nictiz-intern' while reldir is 'XIS-Server')
                 Otherwise we do nothing, because targets only have to output files affected by it. -->
            <xsl:variable name="target" select="$nts.file.dir.properties?target"/>
            
            <xsl:if test="$target = '#default' or (fn:contains(fn:concat('/',$target.dir), $nts.file.dir.properties?reldir.root) and xs:integer($nts.file.dir.properties?targetLevel) = xs:integer($nts.file.dir.properties?rootLevel))">
                <xsl:variable name="srcPropertiesPath" select="concat(., 'src-properties.json')"/>
                
                <xsl:if test="not(unparsed-text-available($srcPropertiesPath))">
                    <xsl:message terminate="yes" select="concat('No src-properties.json file found in path ''', $nts.file.dir.properties?reldir, '''')"/>
                </xsl:if>
                
                <xsl:variable name="srcProperties" select="if (unparsed-text-available($srcPropertiesPath)) then json-doc($srcPropertiesPath) else ()"/>
                
                <xsl:variable name="properties">
                    <map xmlns="http://www.w3.org/2005/xpath-functions">
                        <string key="goal">
                            <xsl:variable name="srcGoal" select="$srcProperties?goal"/>
                            <xsl:choose>
                                <xsl:when test="$srcGoal = '${goal}'">
                                    <xsl:value-of select="$goal"/>
                                </xsl:when>
                                <xsl:when test="not(empty($srcGoal))">
                                    <xsl:value-of select="$srcGoal"/>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:value-of select="$goal"/>
                                </xsl:otherwise>
                            </xsl:choose>
                        </string>
                        
                        <!-- Does not check the fhirVersion in src-properties -->
                        <xsl:if test="not(upper-case($fhirVersion) = ('DSTU1', 'DSTU2', 'STU3', 'R4', 'R4B', 'R5'))">
                            <xsl:message terminate="yes" select="concat('Unrecognized FHIR version: ', $fhirVersion)"/>
                        </xsl:if>
                        <string key="fhirVersion">
                            <xsl:variable name="srcFhirVersion" select="$srcProperties?fhirVersion"/>
                            <xsl:choose>
                                <xsl:when test="$srcFhirVersion = '${fhir.version}'">
                                    <xsl:value-of select="upper-case($fhirVersion)"/>
                                </xsl:when>
                                <xsl:when test="not(empty($srcFhirVersion))">
                                    <xsl:value-of select="upper-case($srcFhirVersion)"/>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:value-of select="upper-case($fhirVersion)"/>
                                </xsl:otherwise>
                            </xsl:choose>
                        </string>
                        
                        <string key="informationStandard">
                            <xsl:variable name="srcInformationStandard" select="$srcProperties?informationStandard"/>
                            <xsl:choose>
                                <xsl:when test="$srcInformationStandard = '${$informationStandard}'">
                                    <xsl:value-of select="$informationStandard"/>
                                </xsl:when>
                                <xsl:when test="not(empty($srcInformationStandard))">
                                    <xsl:value-of select="$srcInformationStandard"/>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:value-of select="$informationStandard"/>
                                </xsl:otherwise>
                            </xsl:choose>
                        </string>
                        <string key="usecase">
                            <xsl:variable name="srcUsecase" select="$srcProperties?usecase"/>
                            <xsl:choose>
                                <xsl:when test="$srcUsecase = '${usecase}'">
                                    <xsl:value-of select="$usecase"/>
                                </xsl:when>
                                <xsl:when test="not(empty($srcUsecase))">
                                    <xsl:value-of select="$srcUsecase"/>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:value-of select="$usecase"/>
                                </xsl:otherwise>
                            </xsl:choose>
                        </string>
                        
                        <xsl:variable name="srcPropertiesRoleName" select="$srcProperties?role?name"/>
                        <xsl:variable name="srcPropertiesRoleDescription" select="$srcProperties?role?description"/>
                        <xsl:if test="empty($srcPropertiesRoleName)">
                            <xsl:message terminate="yes" select="concat('No role.name found in ''', $nts.file.dir.properties?reldir, '/src-properties.json''')"/>
                        </xsl:if>
                        <map key="role">
                            <string key="name">
                                <xsl:value-of select="$srcPropertiesRoleName"/>
                            </string>
                            <xsl:if test="not(empty($srcPropertiesRoleDescription))">
                                <string key="description">
                                    <xsl:value-of select="$srcPropertiesRoleDescription"/>
                                </string>
                            </xsl:if>
                        </map>
                        
                        <xsl:variable name="theCategory" select="$srcProperties?category"/>
                        <xsl:if test="not(empty($theCategory))">
                            <string key="category">
                                <xsl:value-of select="$theCategory"/>
                            </string>
                        </xsl:if>
                        <xsl:variable name="theSubcategory" select="$srcProperties?subcategory"/>
                        <xsl:if test="not(empty($theSubcategory))">
                            <string key="subcategory">
                                <xsl:value-of select="$theSubcategory"/>
                            </string>
                        </xsl:if>
                    </map>
                </xsl:variable>
                
                <xsl:variable name="properties.path">
                    <xsl:value-of select="concat('file:///', translate($outputDir, '\', '/'))"/>
                    <xsl:choose>
                        <xsl:when test="$target != '#default'">
                            <xsl:value-of select="fn:concat('/', $target.dir, $nts.file.dir.properties?reldir.leaf)"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="$nts.file.dir.properties?reldir"/>
                        </xsl:otherwise>
                    </xsl:choose>
                    <xsl:value-of select="'/'"/>
                </xsl:variable>
                
                <xsl:if test="$target != '#default' or unparsed-text-available($srcPropertiesPath)">
                    <xsl:result-document href="{concat($properties.path, '/properties.json')}" method="text" indent="no">
                        <xsl:value-of select="xml-to-json($properties, map {'indent': true()})"/>
                    </xsl:result-document>
                </xsl:if>
            </xsl:if>
        </xsl:for-each>
        
    </xsl:template>
    
    <xsl:template match="/" name="createLoadResourcesProperties">
        <!-- Create an XML representation of the desired JSON structure, which can be written as JSON using xml-to-json. --> 
        <xsl:variable name="properties">
            <map xmlns="http://www.w3.org/2005/xpath-functions">
                <string key="goal">
                    <xsl:value-of select="$goal"/>
                </string>
                <string key="fhirVersion">
                    <xsl:value-of select="upper-case($fhirVersion)"/>
                </string>
                <string key="informationStandard">
                    <xsl:value-of select="$informationStandard"/>
                </string>
                <string key="usecase">
                    <xsl:value-of select="$usecase"/>
                </string>
            </map>
        </xsl:variable>

        <xsl:variable name="properties.path">
            <xsl:value-of select="concat('file:///', translate($outputDir, '\', '/'),'/_LoadResources')"/>
        </xsl:variable>
        
        <xsl:result-document href="{concat($properties.path, '/properties.json')}" method="text" indent="no">
            <xsl:value-of select="xml-to-json($properties, map {'indent': true()})"/>
        </xsl:result-document>

    </xsl:template>
    
</xsl:stylesheet>