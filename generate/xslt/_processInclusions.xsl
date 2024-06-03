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
        This file contains all the templates needed for the inclusion processing step. All templates here have mode "processInclusions".
        It expects the following global parameters to be set:
        - projectComponentFolder
        - commonComponentFolder
    -->
    
    <!-- Expand a nts:include element that uses absolute references with href.
         It will read all f:parts elements in the referenced file and process them further. --> 
    <xsl:template match="nts:include[@href]" mode="processInclusions">
        <xsl:param name="inclusionParameters" tunnel="yes" as="element(nts:with-parameter)*"/>
        
        <xsl:variable name="newInclusionParameters" as="element(nts:with-parameter)*">
            <xsl:copy-of select="$inclusionParameters"/>
            <xsl:variable name="attributesAsParameters">
                <xsl:for-each select="./@*[not(local-name() = ('value', 'scope'))]">
                    <nts:with-parameter name="${local-name(.)}" value="."/>
                </xsl:for-each>
            </xsl:variable>
            <xsl:for-each select="nts:with-parameter | $attributesAsParameters/nts:with-parameter">
                <xsl:copy>
                    <xsl:apply-templates select="@*" mode="processInclusions"/>
                </xsl:copy>
            </xsl:for-each>
        </xsl:variable>
        
        <xsl:variable name="document" as="node()*">
            <xsl:copy-of select="document(@href, .)"/>
        </xsl:variable>
        <xsl:apply-templates select="$document/nts:component/(element()|comment())" mode="processInclusions">
            <xsl:with-param name="inclusionParameters" select="$newInclusionParameters" tunnel="yes"/>
        </xsl:apply-templates>
    </xsl:template>

    <!-- Expand a nts:include element that uses relative references with value and scope.
         It will convert value to a full file path, read all f:parts elements in the referenced file and process them
         further. --> 
    <xsl:template match="nts:include[@value]" mode="processInclusions">
        <xsl:param name="inclusionParameters" tunnel="yes" as="element(nts:with-parameter)*"/>
        
        <xsl:variable name="newInclusionParameters" as="element(nts:with-parameter)*">
            <xsl:copy-of select="$inclusionParameters"/>
            <xsl:variable name="attributesAsParameters">
                <xsl:for-each select="./@*[not(local-name() = 'href')]">
                    <nts:with-parameter name="{local-name(.)}" value="{.}"/>
                </xsl:for-each>
            </xsl:variable>
            <xsl:for-each select="nts:with-parameter | $attributesAsParameters/nts:with-parameter">
                <xsl:copy>
                    <xsl:apply-templates select="@*" mode="processInclusions"/>
                </xsl:copy>
            </xsl:for-each>
        </xsl:variable>
        
        <xsl:variable name="filePath">
            <xsl:choose>
                <xsl:when test="@scope = 'common'">
                    <xsl:value-of select="nts:constructXMLFilePath($commonComponentFolder, @value)"/>
                </xsl:when>
                <xsl:when test="@scope = 'project' or not(@scope)">
                    <xsl:value-of select="nts:constructXMLFilePath($projectComponentFolder, @value)"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:message terminate="yes" select="concat('Unknown inclusion scope ''', @scope, '''')"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:apply-templates select="document(string-join(($filePath), '/'), .)/nts:component/(element()|comment(),.)" mode="processInclusions">
            <xsl:with-param name="inclusionParameters" select="$newInclusionParameters" tunnel="yes"/>
        </xsl:apply-templates>
    </xsl:template>
    
    <!-- Include or exclude elements with the nts:ifset and nts:ifnotset attributes, based on whether the specified 
         parameter is passed in an nts:include. -->
    <xsl:template match="*[@nts:ifset]" mode="processInclusions" priority="2">
        <xsl:param name="scenario" tunnel="yes"/>
        <xsl:param name="inclusionParameters" tunnel="yes" as="element(nts:with-parameter)*"/>
        <xsl:if test="./@nts:ifset = $inclusionParameters/@name/string()">
            <xsl:next-match/>
        </xsl:if>
        <xsl:if test="local-name(.) = ('contentType', 'fixture') and ./@nts:ifset = '_FORMAT' and $scenario = 'server'">
            <xsl:next-match/>
        </xsl:if>
    </xsl:template>
    <xsl:template match="*[@nts:ifnotset]" mode="processInclusions" priority="2">
        <xsl:param name="inclusionParameters" tunnel="yes" as="element(nts:with-parameter)*"/>
        <xsl:if test="not(./@nts:ifnotset = $inclusionParameters/@name/string())">
            <xsl:next-match/>
        </xsl:if>
    </xsl:template>
    
    <!-- Parameter names starting with '_' are excluded here for exclusive internal use. See an example within nts:fixture for '_FORMAT' -->
    <xsl:variable name="parameterChars" select="'[a-zA-Z0-9-][A-Za-z_0-9-]*'"/>
    
    <xsl:template match="@*" mode="processInclusions">
        <xsl:param name="inclusionParameters" as="element(nts:with-parameter)*" tunnel="yes"/>
        <xsl:param name="defaultParameters" as="element(nts:parameter)*" select="ancestor::nts:component[1]/nts:parameter"/>
        <xsl:variable name="componentName" select="tokenize(base-uri(), '/')[last()]"/>
        
        <xsl:variable name="value">
            <xsl:variable name="regexString" select="concat('\{\$(',$parameterChars,')\}')"/>
            <xsl:choose>
                <xsl:when test="matches(., $regexString)"> <!-- Match on an inclusion parameter -->
                    <xsl:analyze-string select="." regex="{$regexString}">
                        <xsl:matching-substring>
                            <xsl:variable name="paramName" select="regex-group(1)"/>
                            <xsl:variable name="replacement" select="$inclusionParameters[@name = $paramName]"/>
                            <xsl:variable name="default" select="$defaultParameters[@name=$paramName and @value]"/>
                            <xsl:choose>
                                <xsl:when test="$paramName != '' and count($replacement) gt 1">
                                    <xsl:message terminate="yes">Parameter '<xsl:value-of select="$paramName"/>' is available twice in nts:component '<xsl:value-of select="$componentName"/>'. Cool, but not supported at the moment. Please use globally unique variable names.</xsl:message>
                                </xsl:when>
                                <xsl:when test="$paramName != '' and count($replacement) = 1">
                                    <xsl:value-of select="$replacement/@value"/>
                                </xsl:when>
                                <xsl:when test="$paramName != '' and count($default) ne 0">
                                    <xsl:value-of select="$default[last()]/@value"/>
                                </xsl:when>
                                <xsl:when test="$paramName = ''">
                                    <xsl:message terminate="yes">An empty parameter name is found in nts:component '<xsl:value-of select="$componentName"/>'. Not cool.</xsl:message>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:message terminate="yes">You used parameter '<xsl:value-of select="$paramName"/>' in nts:component '<xsl:value-of select="$componentName"/>', but no value is available. Not cool.</xsl:message> 
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:matching-substring>
                        <xsl:non-matching-substring>
                            <xsl:value-of select="."/>
                        </xsl:non-matching-substring>
                    </xsl:analyze-string>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="."/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:attribute name="{name()}" namespace="{namespace-uri()}">
            <xsl:value-of select="$value"/>
        </xsl:attribute>
    </xsl:template>

    <!-- Pre-filter in the expand mode to only include elements that are in the target designated using the 'target'
         stylesheet parameter -->
    <xsl:template match="(f:*|nts:*)" mode="processInclusions" priority="3">
        <xsl:param name="target" tunnel="yes"/>
        <xsl:if test=".[$target = tokenize(@nts:in-targets, ' ') or not(@nts:in-targets)]">
            <xsl:next-match/>
        </xsl:if>
    </xsl:template>

    <!-- Default template in the processInclusions mode -->
    <xsl:template match="node()" mode="processInclusions">
        <xsl:copy>
            <xsl:apply-templates select="node()|@*" mode="processInclusions"/>
        </xsl:copy>
    </xsl:template>
    
</xsl:stylesheet>