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
        It expects the following global parameters to be set:
        - fhirVersion (either 'stu3' or 'r4')
    -->
    
    <!-- A list of packages, formatted as a single comma-separated string. --> 
    <xsl:param name="packages"/>
    
    <!-- A list matching packages to their versions. This list is formatted as a single comma-separated string with
         "package=version" entries. --> 
    <xsl:param name="packageVersions" as="xs:string"/>
    
    <!-- The "informationStandard" according to the Conformancelab spec. -->
    <xsl:param name="informationStandard" as="xs:string" required="yes"/>
    
    <!-- The "usecase" according to the Conformancelab spec. -->
    <xsl:param name="usecase" as="xs:string" required="yes"/>
    
    <!-- A comma-separated list of roles that we recognize within the current folder structure. --> 
    <xsl:param name="roles" as="xs:string" required="yes"/>
    
    <!-- A list matching targets to their descriptions. This list is formatted as a single comma-separated string with
         "target=description" entries. The targets are the full folder names, and the descriptions may contain 
         unescaped comma's. -->
    <xsl:param name="targetDescriptions"/>
    
    <!-- A comma separated list of targets that are considered "admin only". -->
    <xsl:param name="adminOnlyTargets"/>
    
    <xsl:template name="generatePropertiesFile">
        <xsl:param name="fileUrl" as="xs:string" required="yes"/>
        <xsl:param name="relFolderPath" as="xs:string" required="yes"/>

        <!-- Create an XML representation of the desired JSON structure, which can be written as JSON using xml-to-json. --> 
        <xsl:variable name="properties">
            <map xmlns="http://www.w3.org/2005/xpath-functions">
                <string key="informationStandard">
                    <xsl:value-of select="$informationStandard"/>
                </string>
                <string key="usecase">
                    <xsl:value-of select="$usecase"/>
                </string>
                
                <xsl:if test="string-length(normalize-space($fhirVersion)) = 0">
                    <xsl:message terminate="yes">No FHIR version has been supplied</xsl:message>
                </xsl:if>
                <string key="fhirVersion">
                    <xsl:value-of select="upper-case($fhirVersion)"/>
                </string>
                
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
                                    <xsl:map-entry key="'target'" select="substring-after($subfolder, concat(., '-'))"/>
                                    <xsl:map-entry key="'folder'" select="$subfolder"/>
                                </xsl:if>
                            </xsl:for-each>
                        </xsl:for-each>
                    </xsl:map>
                </xsl:variable>
                <xsl:if test="not(map:contains($roleFolder, 'role'))">
                    <xsl:message terminate="yes" select="concat('No folder dedicated to a role could be found in path ''', $relFolderPath, '''. Known role names are: ', string-join($roleList, ', '))"/>
                </xsl:if>
                <xsl:variable name="subfolders" as="xs:string*">
                    <xsl:for-each select="tokenize($relFolderPath, '/')">
                        <xsl:if test="string-length(normalize-space(.)) &gt; 0 and not(starts-with(., $roleFolder('role')))">
                            <xsl:value-of select="."/>
                        </xsl:if>
                    </xsl:for-each>
                </xsl:variable>
                
                <string key="role">
                    <xsl:value-of select="$roleFolder('role')"/>
                </string>
                <xsl:if test="$subfolders[1]">
                    <string key="category">
                        <xsl:value-of select="$subfolders[1]"/>
                    </string>
                </xsl:if>
                <xsl:if test="$subfolders[2]">
                    <string key="subcategory">
                        <xsl:value-of select="$subfolders[2]"/>
                    </string>
                </xsl:if>
                <xsl:if test="count($subfolders) &gt; 2">
                    <xsl:message terminate="yes" select="concat('Folders nested too deep: ', $relFolderPath)"/>
                </xsl:if>
                <xsl:if test="$roleFolder('target')">
                    <map key="variant">
                        <string key="name">
                            <xsl:value-of select="$roleFolder('target')"/>
                        </string>
                        <xsl:if test="contains($targetDescriptions, $roleFolder('folder'))">
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
                                <xsl:value-of select="$description"/>
                            </string>
                        </xsl:if>
                    </map>
                </xsl:if>
                
                <xsl:for-each select="for $target in tokenize($adminOnlyTargets, ',') return normalize-space($target)">
                    <xsl:if test=". = $roleFolder('folder')">
                        <boolean key="adminOnly">true</boolean>
                    </xsl:if>
                </xsl:for-each>
                
                <!-- Expand the packages/packageVersions parameters. -->
                <xsl:variable name="packageList" select="for $package in tokenize($packages, ',') return normalize-space($package)"/>
                <xsl:if test="count($packageList) != 0">
                    <array key="packages">
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
                                <string key="package">
                                    <xsl:value-of select="$package"/>
                                </string>
                                <string key="version">
                                    <xsl:value-of select="$version"/>
                                </string>
                            </map>
                        </xsl:for-each>                    
                    </array>
                </xsl:if>
            </map>
        </xsl:variable>
        <xsl:result-document href="{$fileUrl}" method="text" indent="no">
            <xsl:value-of select="xml-to-json($properties, map {'indent': true()})"/>
        </xsl:result-document>
    </xsl:template>    
</xsl:stylesheet>