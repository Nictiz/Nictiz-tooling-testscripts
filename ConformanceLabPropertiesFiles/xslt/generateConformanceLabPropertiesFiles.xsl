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
    
    <!--
        This file contains the machinery to write a ConformanceLab properties file.
    -->

    <xsl:param name="baseDirUrl"/>

    <xsl:param name="fhirVersion" as="xs:string"/>
    
    <!-- The "goal" according to the Conformancelab spec. -->
    <xsl:param name="goal" as="xs:string"/>
    
    <!-- The "informationStandard" according to the Conformancelab spec. -->
    <xsl:param name="informationStandard" as="xs:string"/>
    
    <!-- The "usecase" according to the Conformancelab spec. -->
    <xsl:param name="usecase" as="xs:string"/>
    
    <!-- A comma-separated list of roles that we recognize within the current folder structure. --> 
    <xsl:param name="roles" as="xs:string"/>
    
    <!-- A list matching roles to their descriptions. This list is formatted as a single comma-separated string with
         "role=description" entries. The descriptions may contain unescaped comma's. -->
    <xsl:param name="roleDescriptions" as="xs:string"/>
    
    <!-- A list matching targets to their descriptions. This list is formatted as a single comma-separated string with
         "target=description" entries. The targets are the full folder names, and the descriptions may contain 
         unescaped comma's. -->
    <xsl:param name="targetDescriptions"/>
    
    <!-- A comma separated list of targets that are considered "admin only". -->
    <xsl:param name="adminOnlyTargets"/>

    <!-- A list of packages, formatted as a single comma-separated string. --> 
    <xsl:param name="packages"/>
    
    <!-- A list matching packages to their versions. This list is formatted as a single comma-separated string with
         "package=version" entries. --> 
    <xsl:param name="packageVersions" as="xs:string"/>
    
    <!-- The "server" according to the Conformancelab spec. -->
    <xsl:param name="server" as="xs:string"/>
    
    <!-- A list of default servers per FHIR version/usecase combination. This list if formatted as a comma-separated
         string with "usecase.fhirVersion=server" entries. -->
    <xsl:param name="defaultServers" as="xs:string"/>

    <xsl:template name="generatePropertiesFiles">
        <xsl:for-each select="nts:findFolders(fn:false())">
            <xsl:call-template name="generatePropertiesFile">
                <xsl:with-param name="relFolderPath" select="."/>
                <xsl:with-param name="loadscriptFolder" select="fn:false()"/>
            </xsl:call-template>
        </xsl:for-each>

        <xsl:for-each select="nts:findFolders(fn:true())">
            <xsl:call-template name="generatePropertiesFile">
                <xsl:with-param name="relFolderPath" select="."/>
                <xsl:with-param name="loadscriptFolder" select="fn:true()"/>
            </xsl:call-template>
        </xsl:for-each>
    </xsl:template>
    
    <!-- Return all relative paths of folder with TestScripts in them.
         - loadscriptFolders: If false, find non-loadscript folders only. If true, find loadscript folders only.
    -->
    <xsl:function name="nts:findFolders" as="xs:string*">
        <xsl:param name="loadscriptFolders" as="xs:boolean"/>
        
        <!--
            We need to place property files in all folders containing files, but not in the folders in between or in
            empty folders (and excluding everything starting with an underscore). Getting only the folders with files
            is not trivial in XSLT (or in ANT) unfortunately.
            The approach is to loop over all TestScript content in folders and nested folders using collection(),
            extract the uri of the TestScript using base-uri(), and than extract the relative path beneath baseDirUrl
            from that. Once we have the collection, we can de-duplicate it.
            The assumption is that at least, by working with file uri's, we can assume that the path separator is
            always a backslash, so we don't need to worry about *that*.
        -->
        <xsl:variable name="path" select="replace($baseDirUrl, 'file:/*', '')"/>
        <xsl:variable name="unfiltered" as="xs:string*">
            <xsl:for-each select="collection(iri-to-uri(concat($baseDirUrl, '?select=', '*.xml;recurse=yes')))//f:TestScript">
                <!-- One would assume that working with file uri's we have a stable 'base part' with scheme,
                     slashes, etc. so we can strip that from the file uri and be left with the relative path.
                     But nonono, that would be simple. So base-uri() returns (at this time and place at least) a
                     file uri with a single slash instead of three slashes. Our replace strategy now has to account
                     for any number of forward slashes following the 'file:' part.
                -->
                <xsl:variable name="relative" select="replace(base-uri(.), concat('file:/+', $path), '')"/>
                <xsl:choose>
                    <xsl:when test="not($loadscriptFolders) and not(starts-with($relative, '/_'))">
                        <!-- Filter out folders starting with an underscore in 'normal' mode -->
                        <xsl:value-of select="replace($relative, '/(.*)/.*?\.xml', '$1')"/>
                    </xsl:when>
                    <xsl:when test="$loadscriptFolders and starts-with($relative, '/_LoadResources')">
                        <!-- Only include folders that are explicitly called _LoadResources when looking for loadscript
                             folders. -->
                        <xsl:value-of select="replace($relative, '/(.*)/.*?\.xml', '$1')"/>
                    </xsl:when>
                </xsl:choose>
            </xsl:for-each>
        </xsl:variable>
        
        <xsl:copy-of select="distinct-values($unfiltered)"/>
    </xsl:function>
    
    <!-- Generate a property file for the specified folder.
         - relFolderPath: the relative path to the folder.
         - loadscriptFolder: boolean to indicate if this is a loadscript folder, to which not all property's apply.
    -->
    <xsl:template name="generatePropertiesFile">
        <xsl:param name="relFolderPath" as="xs:string" required="yes"/>
        <xsl:param name="loadscriptFolder" as="xs:boolean" required="yes"/>
        
        <!-- Check if properties.json already exists in this folder. If so, the value of each property set in this file will overrule the generated value in the output properties.json -->
        <xsl:variable name="srcPropertiesPath" select="concat($baseDirUrl, '/', $relFolderPath, '/properties.json')"/>
        <xsl:variable name="srcProperties" select="if (unparsed-text-available($srcPropertiesPath)) then parse-json(unparsed-text($srcPropertiesPath)) else ()"/>
        
        <!-- Here we declare all properties, taking into account potential overrules from srcProperties -->
        <xsl:variable name="theGoal" select="($srcProperties?goal,$goal)[1]"/>
        <xsl:variable name="theFhirVersion" select="($srcProperties?fhirVersion,$fhirVersion)[1]"/>
        <xsl:variable name="theInformationStandard" select="($srcProperties?informationStandard,$informationStandard)[1]"/>
        <xsl:variable name="theUsecase" select="($srcProperties?usecase,$usecase)[1]"/>
        
        <!-- For roles, we do something slightly different -->
        <xsl:variable name="srcPropertiesRoleName" select="$srcProperties?role?name"/>
        <xsl:variable name="srcPropertiesRoleDescription" select="$srcProperties?role?description"/>
        
        <!-- If there is a target/variant, this should be filled. Description is optional -->
        <xsl:variable name="srcPropertiesVariantName" select="$srcProperties?variant?name"/>
        <xsl:variable name="srcPropertiesVariantDescription" select="$srcProperties?variant?description"/>
        
        <xsl:variable name="roleList" select="for $role in tokenize($roles, ',') return fn:normalize-space($role)"/>
        <!--
             Get all the subfolders between the ouput root and the output file, and fish out the folder that
             specifies the role (which may have an additional target appended, so it's a match on the start of
             the folder name).
             First element is discarded because it is empty ($relFolderPath always starts with a '/')
        -->
        <xsl:variable name="roleFolder" as="map(*)">
            <xsl:map>
                <xsl:for-each select="tokenize($relFolderPath, '/')">
                    <xsl:variable name="subfolder" select="."/>
                    <xsl:for-each select="$roleList">
                        <xsl:variable name="role" select="."/>
                        <xsl:if test="starts-with($subfolder, $role)">
                            <xsl:map-entry key="'role'" select="$role"/>
                            <xsl:map-entry key="'folder'" select="$subfolder"/>
                        </xsl:if>
                    </xsl:for-each>
                </xsl:for-each>
            </xsl:map>
        </xsl:variable>
        <xsl:if test="not(map:contains($roleFolder, 'role')) and empty($srcPropertiesRoleName) and not($loadscriptFolder)">
            <xsl:message terminate="yes" select="concat('No folder dedicated to a role could be found in path ''', $relFolderPath, '''. Known role names are: ', string-join($roleList, ', '))"/>
        </xsl:if>
        
        <xsl:variable name="subfolders" as="xs:string*">
            <xsl:for-each select="tokenize($relFolderPath, '/')">
                <xsl:if test="string-length(normalize-space(.)) &gt; 0 and not(starts-with(., $roleFolder('role')))">
                    <xsl:value-of select="."/>
                </xsl:if>
            </xsl:for-each>
        </xsl:variable>
        <xsl:if test="count($subfolders) &gt; 2 and (empty($srcProperties?category) and empty($srcProperties?subcategory))">
            <xsl:message terminate="yes" select="concat('Folders nested too deep: ', $relFolderPath)"/>
        </xsl:if>
        
        <xsl:variable name="theCategory" select="($srcProperties?category,$subfolders[1])[1]"/>
        <xsl:variable name="theSubcategory" select="($srcProperties?subcategory,$subfolders[2])[1]"/>
        
        <!-- Create an XML representation of the desired JSON structure, which can be written as JSON using xml-to-json. --> 
        <xsl:variable name="properties">
            <map xmlns="http://www.w3.org/2005/xpath-functions">
                <xsl:if test="not($theGoal = ('Test', 'Cert'))">
                    <xsl:message terminate="yes" select="concat('Unrecognized goal: ', $theGoal, '. It should be either ''Test'' or ''Cert''.')"/>
                </xsl:if>
                <string key="goal">
                    <xsl:value-of select="$theGoal"/>
                </string>
                
                <xsl:if test="string-length(normalize-space($theFhirVersion)) = 0">
                    <xsl:message terminate="yes">No FHIR version has been supplied</xsl:message>
                </xsl:if>
                <xsl:if test="not(upper-case($theFhirVersion) = ('DSTU1', 'DSTU2', 'STU3', 'R4', 'R4B', 'R5'))">
                    <xsl:message terminate="yes" select="concat('Unrecognized FHIR version: ', $theFhirVersion)"/>
                </xsl:if>
                <string key="fhirVersion">
                    <xsl:value-of select="upper-case($theFhirVersion)"/>
                </string>
                
                <string key="informationStandard">
                    <xsl:value-of select="$theInformationStandard"/>
                </string>
                <string key="usecase">
                    <xsl:value-of select="$theUsecase"/>
                </string>
                
                <xsl:if test="not($loadscriptFolder)">
                    <xsl:choose>
                        <xsl:when test="not(empty($srcPropertiesRoleName))">
                            <map key="role">
                                <string key="name">
                                    <xsl:value-of select="$srcPropertiesRoleName"/>
                                </string>
                                <!-- If there is a role.name override, we also expect role.description to be overridden to prevent al kinds of unwanted scenarios -->
                                <xsl:if test="not(empty($srcPropertiesRoleDescription))">
                                    <string key="description">
                                        <xsl:value-of select="$srcPropertiesRoleDescription"/>
                                    </string>
                                </xsl:if>
                            </map>
                        </xsl:when>
                        <xsl:otherwise>
                            <map key="role">
                                <string key="name">
                                    <xsl:value-of select="$roleFolder('role')"/>
                                </string>
                                <xsl:if test="contains($roleDescriptions, concat($roleFolder('role'), '='))">
                                    <!--
                                         The $targetRoles string is formatted as a single string with role=description
                                         pairs, separated by comma's. The descriptions are literaly what's in the ant properties
                                         file, no escaping, and so it might contain comma's and we can't just split on comma's.
                                         So the surest way to fish out the description is to use a regex where we search for
                                         'our role=' up until the start of the next pair (or the end of the string). The
                                         start of the next pair always begins by a comma, followed by a set of non-whitespace
                                         characters, followed by an = sign, so that's our clue.
                                    -->
                                    <xsl:variable name="pattern" select="concat('.*', $roleFolder('role'), '=(.*?)($|,\S+=.*)')"/>
                                    <xsl:variable name="description" select="replace($roleDescriptions, $pattern, '$1')"/>
                                    <string key="description">
                                        <xsl:value-of select="$description"/>
                                    </string>
                                </xsl:if>
                            </map>
                        </xsl:otherwise>
                    </xsl:choose>
                    
                    <xsl:if test="not(empty($srcPropertiesVariantName))">
                        <map key="variant">
                            <string key="name">
                                <xsl:value-of select="$srcPropertiesVariantName"/>
                            </string>
                            <xsl:if test="not(empty($roleFolder('folder'))) and contains($targetDescriptions, $roleFolder('folder'))">
                                <!--
                                     The $targetDescriptions string is formatted as a single string with target=description
                                     pairs, separated by comma's. The descriptions are literaly what's in the ant properties
                                     file, no escaping, and so it might contain comma's and we can't just split on comma's.
                                     So the surest way to fish out the description is to use a regex where we search for
                                     'our target=' up until the start of the next pair (or the end of the string). The
                                     start of the next pair always begins by a comma and the role, so that's our clue.
                                -->
                                <xsl:variable name="pattern" select="concat('.*', $roleFolder('folder'), '=(.*?)($|,', $roleFolder('role'), ').*')"/>
                                <xsl:variable name="description" select="replace($targetDescriptions, $pattern, '$1')"/>
                                <string key="description">
                                    <xsl:value-of select="($srcPropertiesVariantDescription,$description)[1]"/>
                                </string>
                            </xsl:if>
                        </map>
                    </xsl:if>
                    
                    <xsl:variable name="folder" select="tokenize($relFolderPath, '/')[last()]"/>
                    <xsl:for-each select="for $target in tokenize($adminOnlyTargets, ',') return normalize-space($target)">
                        <xsl:if test=". = $folder or . = $roleFolder('folder') or $srcProperties?adminOnly = 'true'">
                            <boolean key="adminOnly">true</boolean>
                        </xsl:if>
                    </xsl:for-each>
                    
                    
                    <xsl:if test="not(empty($theCategory))">
                        <string key="category">
                            <xsl:value-of select="$theCategory"/>
                        </string>
                    </xsl:if>
                    <xsl:if test="not(empty($theSubcategory))">
                        <string key="subcategory">
                            <xsl:value-of select="$theSubcategory"/>
                        </string>
                    </xsl:if>
                    
                    <!-- Expand the packages/packageVersions parameters. -->
                    <!-- Overriding packages isn't supported -->
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
                </xsl:if>
                
                <!-- Expand the server/defaultServers parameters. -->
                <!-- Overriding servers isn't supported -->
                <xsl:variable name="resolvedServer" as="xs:string*">
                    <xsl:variable name="serverMap" select="map:merge(for $entry in tokenize($defaultServers, ',') return let $pair := tokenize($entry, '=') return map:entry($pair[1], $pair[2]))"/>
                    <xsl:choose>
                        <xsl:when test="string-length(normalize-space($server)) &gt; 0">
                            <!-- server explicitly set -->
                            <xsl:value-of select="$server"/>
                        </xsl:when>
                        <xsl:when test="map:contains($serverMap, concat($usecase, '.', $fhirVersion))">
                            <!-- default server based on use case and FHIR version -->
                            <xsl:value-of select="map:get($serverMap, concat($usecase, '.', $fhirVersion))"/>
                        </xsl:when>
                        <xsl:when test="map:contains($serverMap, concat('#default', '.', $fhirVersion))">
                            <!-- default server for the FHIR version, ignoring the use case -->
                            <xsl:value-of select="map:get($serverMap, concat('#default', '.', $fhirVersion))"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:message terminate="yes">Can't figure out which server to use</xsl:message>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <string key="serverAlias">
                    <xsl:value-of select="$resolvedServer"/>
                </string>
            </map>
        </xsl:variable>
        <xsl:result-document href="{concat($baseDirUrl, '/', $relFolderPath, '/properties.json')}" method="text" indent="no">
            <xsl:value-of select="xml-to-json($properties, map {'indent': true()})"/>
        </xsl:result-document>
    </xsl:template>
</xsl:stylesheet>