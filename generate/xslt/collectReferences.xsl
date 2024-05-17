<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:fn="http://www.w3.org/2005/xpath-functions" version="2.0"
    xmlns:f="http://hl7.org/fhir"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    exclude-result-prefixes="#all">
    <xsl:output method="text"/>
    <xsl:strip-space elements="*"/>

    <!-- Create a de-duplicated list of all fixtures and rules referenced from the TestScript resource in a folder and
         its subfolders, formatted as strings that can be read by Ant. Reading that output by Ant will result in the
         property's "fixtures" and "rules", each containing a list of files separated by semicolons.
         Parameters:
         - inputDir: the directory containing TestScript resources, directly and in subdirectory's.
         - referencesFile: the path to the resulting Ant propertyfile.
         - includesDir: can be given as the part that should be removed from the fixture/rules path.
    -->
    
    <xsl:param name="inputDir" required="yes"/>
    <xsl:param name="referencesFile" required="yes"/>
    <xsl:param name="includesDir" select="'../_reference/'"/>
    
    <xsl:variable name="includesDirNormalized">
        <xsl:choose>
            <xsl:when test="ends-with($includesDir, '/')">
                <xsl:value-of select="$includesDir"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="concat($includesDir, '/')"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>

    <xsl:template match="/" name="collectReferencesInFolder">
        <xsl:param name="testScripts" select="collection(concat('file:///', $inputDir, '?select=*.xml;recurse=yes'))"/>
        
        <xsl:variable name="fixtures" as="xs:string*">
            <xsl:for-each select="$testScripts//f:fixture">
                <xsl:value-of select="substring-after(f:resource/f:reference/@value, $includesDirNormalized)"/>        
            </xsl:for-each>
        </xsl:variable>

        <xsl:variable name="rules" as="xs:string*">
            <xsl:for-each select="$testScripts//f:extension[@url = 'http://touchstone.aegis.net/touchstone/fhir/testing/StructureDefinition/testscript-rule']">
                <xsl:value-of select="substring-after(f:extension[@url = 'path']/f:valueString/@value, $includesDirNormalized)"/>
            </xsl:for-each>
        </xsl:variable>
        
        <xsl:result-document href="{concat('file:///', fn:translate($referencesFile, '\', '/'))}" method="text">
            <xsl:text>fixtures=</xsl:text>
            <xsl:for-each select="distinct-values($fixtures)">
                <xsl:value-of select="."/>
                <xsl:text>;</xsl:text>
            </xsl:for-each>
            <xsl:text>&#xA;</xsl:text>
            <xsl:text>rules=</xsl:text>
            <xsl:for-each select="distinct-values($rules)">
                <xsl:value-of select="."/>
                <xsl:text>;</xsl:text>
            </xsl:for-each>
        </xsl:result-document>
        
    </xsl:template>
</xsl:stylesheet>