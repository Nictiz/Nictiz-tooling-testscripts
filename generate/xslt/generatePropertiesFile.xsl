<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0"
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
    
    <xsl:template name="generatePropertiesFile">
        <xsl:param name="fileUrl" as="xs:string" required="yes"/>
        
        <xsl:result-document href="{$fileUrl}" method="text" indent="no">
            <xsl:if test="string-length(normalize-space($fhirVersion)) = 0">
                <xsl:message terminate="yes">No FHIR version has been supplied</xsl:message>
            </xsl:if>
            <xsl:copy-of select="concat('- fhirVersion: ', upper-case($fhirVersion), '&#x0A;')"/>
            
            <!-- Expand the packages/packageVersions parameters. -->
            <xsl:variable name="packageList" select="for $package in tokenize($packages, ',') return normalize-space($package)"/>
            <xsl:if test="count($packageList) != 0">
                <xsl:text>- packages:&#x0A;</xsl:text>
            </xsl:if>
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
                <xsl:copy-of select="concat('  - ', $package, ': ', $version)"/>
            </xsl:for-each>            
        </xsl:result-document>
    </xsl:template>
    
</xsl:stylesheet>