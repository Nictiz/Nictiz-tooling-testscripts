
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
    
    <!-- A list matching targets to their descriptions. This list is formatted as a single comma-separated string with
         "target=description" entries. The targets are the full folder names, and the descriptions may contain 
         unescaped comma's. -->
    <xsl:param name="targetDescriptions"/>
    
    <!-- All targets part of this build -->
    <xsl:param name="targets"/>
    
    <!-- A comma separated list of targets that are considered "admin only". -->
    <xsl:param name="adminOnlyTargets"/>
    
    <!-- A list of packages, formatted as a single comma-separated string. --> 
    <xsl:param name="packages"/>
    
    <!-- A list matching packages to their versions. This list is formatted as a single comma-separated string with
         "package=version" entries. --> 
    <xsl:param name="packageVersions" as="xs:string"/>
        
    <!-- An NTS input file can nominate elements to only be included in specific named targets using the nts:only-in
         attribute. The "target.dir" parameter (which defaults to '#default' if no other target is specified) contains
         the full target directory defined in property 'targets.additional' (comma separated) in the build properties.
         For example: 'XIS-Server-Nictiz-intern' or 'MedicationData/Send-Nictiz-intern'. The actual target name used in
         an NTS-file is extracted from this. -->
    <xsl:param name="target.dir" select="'#default'"/>
    
    <!-- The "serverAlias" according to the Conformancelab spec. -->
    <xsl:param name="serverAlias" as="xs:string"/>
    
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
                            <xsl:call-template name="getPropertyValue">
                                <xsl:with-param name="antProperty" select="'goal'"/>
                                <xsl:with-param name="antValue" select="$goal"/>
                                <xsl:with-param name="srcProperty" select="'goal'"/>
                                <xsl:with-param name="srcProperties" select="$srcProperties"/>
                                <xsl:with-param name="nts.file.dir.properties" select="$nts.file.dir.properties"/>
                            </xsl:call-template>
                        </string>

                        <!-- Does not check the fhirVersion in src-properties -->
                        <xsl:if test="not(upper-case($fhirVersion) = ('DSTU1', 'DSTU2', 'STU3', 'R4', 'R4B', 'R5'))">
                            <xsl:message terminate="yes" select="concat('Unrecognized FHIR version: ', $fhirVersion)"/>
                        </xsl:if>
                        <string key="fhirVersion">
                            <xsl:variable name="theFhirVersion">
                                <xsl:call-template name="getPropertyValue">
                                    <xsl:with-param name="antProperty" select="'fhir.version'"/>
                                    <xsl:with-param name="antValue" select="$fhirVersion"/>
                                    <xsl:with-param name="srcProperty" select="'fhirVersion'"/>
                                <xsl:with-param name="srcProperties" select="$srcProperties"/>
                                <xsl:with-param name="nts.file.dir.properties" select="$nts.file.dir.properties"/>
                                </xsl:call-template>
                            </xsl:variable>
                            <xsl:value-of select="upper-case($theFhirVersion)"/>
                        </string>
                        
                        <string key="informationStandard">
                            <xsl:call-template name="getPropertyValue">
                                <xsl:with-param name="antProperty" select="'informationStandard'"/>
                                <xsl:with-param name="antValue" select="$informationStandard"/>
                                <xsl:with-param name="srcProperty" select="'informationStandard'"/>
                                <xsl:with-param name="srcProperties" select="$srcProperties"/>
                                <xsl:with-param name="nts.file.dir.properties" select="$nts.file.dir.properties"/>
                            </xsl:call-template>
                        </string>
                        <string key="usecase">
                            <xsl:call-template name="getPropertyValue">
                                <xsl:with-param name="antProperty" select="'usecase'"/>
                                <xsl:with-param name="antValue" select="$usecase"/>
                                <xsl:with-param name="srcProperty" select="'usecase'"/>
                                <xsl:with-param name="srcProperties" select="$srcProperties"/>
                                <xsl:with-param name="nts.file.dir.properties" select="$nts.file.dir.properties"/>
                            </xsl:call-template>
                        </string>
                        
                        <xsl:variable name="srcPropertiesRoleName" select="$srcProperties?role?name"/>
                        <xsl:variable name="srcPropertiesRoleDescription" select="$srcProperties?role?description"/>
                        <xsl:if test="empty($srcPropertiesRoleName)">
                            <xsl:message terminate="yes" select="concat('No ''role.name'' property found in ''', $nts.file.dir.properties?reldir, '/src-properties.json''')"/>
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
                        
                        <!-- Possible scenarios:
                        - Target is #default and $srcPropertiesVariantName is empty - do nothing
                        - Target is not #default and $srcPropertiesVariantName is empty - add target as variant
                        -->
                        <xsl:if test="not($target = '#default')">
                            <!--
                                 The $targetDescriptions string is formatted as a single string with target=description
                                 pairs, separated by comma's. The descriptions are literaly what's in the ant properties
                                 file, no escaping, and so it might contain comma's and we can't just split on comma's.
                                 So the surest way to fish out the description is to use a regex where we search for
                                 'our target=' up until the start of the next pair (or the end of the string). The
                                 start of the next pair always begins by a comma and one of the other targets, so that's our clue.
                            -->
                            <xsl:variable name="pattern" select="concat('.*', $target.dir, '=(.*?)($|,(', replace($targets,',','|'), '))')"/>
                            <xsl:variable name="description">
                                <xsl:analyze-string select="$targetDescriptions" regex="{$pattern}">
                                    <xsl:matching-substring>
                                        <xsl:value-of select="regex-group(1)"/>
                                    </xsl:matching-substring>
                                </xsl:analyze-string>
                            </xsl:variable>
                            <map key="variant">
                                <string key="name">
                                    <xsl:value-of select="$target"/>
                                </string>
                                <xsl:if test="string-length($description) gt 0">
                                    <string key="description">
                                        <xsl:value-of select="$description"/>
                                    </string>
                                </xsl:if>
                            </map>
                        </xsl:if>
                        
                        <xsl:variable name="srcPropertiesAdminOnly" select="$srcProperties?adminOnly"/>
                        <xsl:choose>
                            <xsl:when test="$srcPropertiesAdminOnly = true()">
                                <boolean key="adminOnly">true</boolean>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:for-each select="for $adminOnlyTarget in tokenize($adminOnlyTargets, ',') return normalize-space($adminOnlyTarget)">
                                    <xsl:if test=". = $target.dir">
                                        <boolean key="adminOnly">true</boolean>
                                    </xsl:if>
                                </xsl:for-each>
                            </xsl:otherwise>
                        </xsl:choose>
                        
                        <xsl:variable name="packageList" select="for $package in tokenize($packages, ',') return normalize-space($package)"/>
                        <xsl:if test="count($packageList) != 0">
                            <array key="fhirPackage">
                                <xsl:for-each select="$packageList">
                                    <xsl:variable name="package" select="."/>
                                    
                                    <!-- The packageVersions parameter is a string formatted as a comma separated list with
                                         'package=version' entries. We use a simple regex approach to extact the version for the
                                         specified canonical. -->
                                    <xsl:variable name="version">
                                        <xsl:for-each select="tokenize($packageVersions, ',')">
                                            <xsl:variable name="parts" select="tokenize(., '=')"/>
                                            <xsl:if test="$parts[1] = $package">
                                                <xsl:value-of select="$parts[2]"/>
                                            </xsl:if>
                                        </xsl:for-each>
                                    </xsl:variable>
                                    <xsl:if test="string-length($version) = 0">
                                        <xsl:message terminate="yes" select="concat('No version has been defined for package ', $package)"/>
                                    </xsl:if>
                                    <map>
                                        <string key="name">
                                            <xsl:value-of select="$package"/>
                                        </string>
                                        <string key="version">
                                            <xsl:value-of select="$version"/>
                                        </string>
                                    </map>
                                </xsl:for-each>                    
                            </array>
                        </xsl:if>
                        
                        <string key="serverAlias">
                            <xsl:call-template name="getPropertyValue">
                                <xsl:with-param name="antProperty" select="'serverAlias'"/>
                                <xsl:with-param name="antValue" select="$serverAlias"/>
                                <xsl:with-param name="srcProperty" select="'serverAlias'"/>
                                <xsl:with-param name="srcProperties" select="$srcProperties"/>
                                <xsl:with-param name="nts.file.dir.properties" select="$nts.file.dir.properties"/>
                            </xsl:call-template>
                        </string>
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
        <xsl:if test="empty($goal) or $goal = '${goal}'">
            <xsl:message terminate="yes" select="concat('No ''goal'' property found in ''', $inputDir, '/build.properties''')"/>
        </xsl:if>
        <xsl:if test="empty($fhirVersion) or $fhirVersion = '${fhir.version}'">
            <xsl:message terminate="yes" select="concat('No ''fhir.version'' property found in ''', $inputDir, '/build.properties''')"/>
        </xsl:if>
        <xsl:if test="empty($informationStandard) or $informationStandard = '${informationStandard}'">
            <xsl:message terminate="yes" select="concat('No ''informationStandard'' property found in ''', $inputDir, '/build.properties''')"/>
        </xsl:if>
        <xsl:if test="empty($usecase) or $usecase = '${usecase}'">
            <xsl:message terminate="yes" select="concat('No ''usecase'' property found in ''', $inputDir, '/build.properties''')"/>
        </xsl:if>
        <xsl:if test="empty($serverAlias) or $serverAlias = '${serverAlias}'">
            <xsl:message terminate="yes" select="concat('No ''serverAlias'' property found in ''', $inputDir, '/build.properties''')"/>
        </xsl:if>

        <!-- Only generate properties file if a loadresources file actually exists. Bit hacky maybe, but it works because of conventions -->
        <xsl:if test="unparsed-text-available(concat('file:///', translate($outputDir, '\', '/'),'/_LoadResources/load-resources-purgecreateupdate-xml.xml'))">
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
                    <string key="serverAlias">
                        <xsl:value-of select="$serverAlias"/>
                    </string>
                </map>
            </xsl:variable>
            
            <xsl:variable name="properties.path">
                <xsl:value-of select="concat('file:///', translate($outputDir, '\', '/'),'/_LoadResources')"/>
            </xsl:variable>
            
            <xsl:result-document href="{concat($properties.path, '/properties.json')}" method="text" indent="no">
                <xsl:value-of select="xml-to-json($properties, map {'indent': true()})"/>
            </xsl:result-document>
        </xsl:if>
    </xsl:template>
    
    <xsl:template name="getPropertyValue">
        <xsl:param name="antProperty"/>
        <xsl:param name="antValue"/>
        <xsl:param name="srcProperty"/>
        <xsl:param name="srcProperties"/>
        <xsl:param name="nts.file.dir.properties"/>
        
        <xsl:variable name="srcValue" select="map:get($srcProperties, $srcProperty)"/>
        <xsl:choose>
            <xsl:when test="$srcValue = concat('${', $antProperty, '}')">
                <xsl:value-of select="$antValue"/>
            </xsl:when>
            <xsl:when test="not(empty($srcValue))">
                <xsl:value-of select="$srcValue"/>
            </xsl:when>
            <xsl:when test="empty($srcValue) and (empty($antValue) or $antValue = concat('${', $antProperty, '}'))">
                <xsl:message terminate="yes" select="'No ''', $srcProperty ,''' property found in ''', $nts.file.dir.properties?reldir, 'src-properties.json'' and build.properties'"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$antValue"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
</xsl:stylesheet>