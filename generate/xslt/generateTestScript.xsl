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
    
    <!-- The folder where components for this project can be found, relative to this file. -->
    <xsl:param name="projectComponentFolder" select="'../_componenents/'"/>
    
    <!-- The folder where the common components for TestScript generation can be found. -->
    <xsl:param name="commonComponentFolder" select="'../../common-asserts/'"/>
    
    <!-- Optional string that will be appended verbatim to the verson string. If there is no version element in the
         input, it will be set to this parameter. -->
    <xsl:param name="versionAddition" select="''"/>
    
    <xsl:include href="_processInclusions.xsl"/>
    <xsl:include href="_expand.xsl"/>
    <xsl:include href="_generateContentAsserts.xsl"/>
    <xsl:include href="_filter.xsl"/>

    <!-- The main template, which will call the remaining templates. -->
    <xsl:template name="generate" match="f:TestScript">       
        <xsl:param name="expectedResponseFormat" tunnel="yes"/>
        <xsl:variable name="scenario" select="@nts:scenario"/>
        
        <!-- Capture the base path in a variable, because the relative path changes with nested includes, leading to Patient token errors -->
        <xsl:variable name="basePath">
            <xsl:variable name="tokenize" select="tokenize(base-uri(), '/')"/>
            <xsl:value-of select="string-join($tokenize[position() lt last()], '/')"/>
        </xsl:variable>
        
        <!-- Sanity check the expectedResponseFormat parameter -->
        <xsl:if test="$expectedResponseFormat != '' and $scenario != 'server'">
            <xsl:message select="'Parameter ''expectedResponseFormat'' only has a meaning when nts:scenario is ''server'''"></xsl:message>
        </xsl:if>
        <xsl:if test="$scenario = 'server' and not($expectedResponseFormat = ('xml', 'json'))">
            <xsl:message terminate="yes" select="concat('Invalid value ''', $expectedResponseFormat, ''' for parameter ''expectedResponseFormat''; should be either ''xml'' or ''json''')"></xsl:message>
        </xsl:if>

        <!-- Extract the authorization tokens specified using the nts:authToken element(s). These tokens can then be used within 
             the nts:authHeader element, referenced by their id. -->
        <xsl:if test="count(//nts:authToken[@patientResourceId]) &gt; 0 and not($tokensJsonFile)">
            <xsl:message terminate="yes">If you use the nts:authToken element, you need to pass in a file containing the tokens using the tokensJsonFile parameter.</xsl:message>
        </xsl:if>
        <xsl:if test="count(//nts:authToken[not(@id)]) &gt; 1">
            <xsl:message terminate="yes">When using multiple nts:authToken elements, at most one may have the default id. All other instances must be uniquely identified with an id.</xsl:message>
        </xsl:if>
        <xsl:variable name="authTokens" as="element(nts:authToken)*">
            <xsl:for-each select="//nts:authToken[@patientResourceId]">
                <xsl:variable name="id" select="if (.[@id]) then concat('patient-token-',@id) else concat('patient-token-',@patientResourceId)"/>
                <xsl:copy-of select="nts:resolveAuthToken(./@patientResourceId, $id, true())"/>
            </xsl:for-each>
        </xsl:variable>
        
        <!-- Seed the parameters used during expansion with the id's of nts:authToken declarations.
             The value of these "magic" parameters depend on the scenario. For server scripts, this will be expanded
             to a corresponding TestScript variable. For client scripts, this will contain the literal content of the
             token. -->
        <xsl:variable name="inclusionParameters" as="element(nts:with-parameter)*">
            <xsl:for-each select="$authTokens">
                <xsl:if test="$scenario = 'server'">
                    <nts:with-parameter name="{./@id}" value="{concat('${', ./@id, '}')}"/>    
                </xsl:if>
                <xsl:if test="$scenario = 'client'">
                    <nts:with-parameter name="{./@id}" value="{./@token}"/>
                </xsl:if>
            </xsl:for-each>
        </xsl:variable>

        <!-- The process to generate the final TestScript resources consists of multiple steps:
             1. First, all inclusions (and their recursive inclusions) are processed to produce a single document.
                This is done by the templates with the "processInclusions" mode.
             2. Then, all (other) nts:tags except nts:contentAsserts are "expanded" in-place to the corresponding
                FHIR TestScript snippet. This is done by the templates with the "expand" mode.
             4. Then the content asserts are generated. This is a separate step, because it is quite involved.
             3. At last, the result is filtered: all the resulting bits are de-duplicated, put in the proper order,
                and all required metadata is added. This is done by the templates with the "filter" mode.
        -->
        
        <!-- Step 1: process all inclusions -->
        <xsl:variable name="inclusionsProcessed">
            <xsl:apply-templates mode="processInclusions" select=".">
                <xsl:with-param name="scenario" select="$scenario" tunnel="yes"/>
                <xsl:with-param name="inclusionParameters" select="$inclusionParameters" tunnel="yes"/>
            </xsl:apply-templates>
        </xsl:variable>

        <!-- Step 2: expand all the Nictiz inclusion elements to their FHIR representation --> 
        <xsl:variable name="expanded">
            <xsl:apply-templates mode="expand" select="$inclusionsProcessed">
                <xsl:with-param name="scenario" select="$scenario" tunnel="yes"/>
                <xsl:with-param name="expectedResponseFormat" select="$expectedResponseFormat" tunnel="yes"/>
                <xsl:with-param name="basePath" select="$basePath" tunnel="yes"/>
                <xsl:with-param name="authTokens" select="$authTokens" tunnel="yes"/>
            </xsl:apply-templates>
        </xsl:variable>
    
        <!-- Step 3: generate the content asserts --> 
        <xsl:variable name="withContentAsserts">
            <xsl:apply-templates mode="generateContentAsserts" select="$expanded">
                <xsl:with-param name="scenario" select="$scenario" tunnel="yes"/>
                <xsl:with-param name="basePath" select="$basePath" tunnel="yes"/>
            </xsl:apply-templates>
        </xsl:variable>

        <!-- Step 4: Filter the expanded TestScript and produce the final output. This will add the required elements
             and put everything in the right position --> 
        <xsl:apply-templates mode="filter" select="$withContentAsserts">
            <xsl:with-param name="fixtures" select="$withContentAsserts//f:fixture" tunnel="yes"/>
            <xsl:with-param name="profiles" select="$withContentAsserts//f:profile[not(ancestor::f:origin | ancestor::f:destination)]" tunnel="yes"/>
            <xsl:with-param name="variables" select="$withContentAsserts//f:variable" tunnel="yes"/>
            <xsl:with-param name="rules" select="$withContentAsserts//f:extension[@url = 'http://touchstone.aegis.net/touchstone/fhir/testing/StructureDefinition/testscript-rule']" tunnel="yes"/>
            <xsl:with-param name="scenario" select="$scenario" tunnel="yes"/>
            <xsl:with-param name="expectedResponseFormat" select="$expectedResponseFormat" tunnel="yes"/>
        </xsl:apply-templates>
    </xsl:template>
        
    <!-- Fix to pretty print output - strip-space does not seem to function when being called from ANT -->
    <xsl:template match="text()[not(normalize-space(.))]" mode="#all"/>
    
    <!-- === Here be functions ==================================================================================== -->
    
    <!-- Construct an XML file path from the elements.
         param base is the folder where the XML file resides
         param filename is the name of the XML file in the folder
         return the full path to the file, optionally appending the .xml extension to the filename if it doesn't
                already have it. -->
    <xsl:function name="nts:constructXMLFilePath" as="xs:string">
        <xsl:param name="base" as="xs:string" />
        <xsl:param name="filename" as="xs:string" />
        
        <xsl:variable name="fullFilename" select="nts:addXMLExtension($filename)"/>
        <xsl:choose>
            <!-- If path is absolute - Unix/MacOS and Windows -->
            <xsl:when test="not(starts-with($base, 'file:')) and (starts-with($base,'/') or matches($base,'^[A-Za-z]:[/\\]'))">
                <xsl:value-of select="concat('file:///',nts:constructFilePath($base,$fullFilename))"/>
            </xsl:when>
            <!-- Else relative -->
            <xsl:otherwise>
                <xsl:value-of select="nts:constructFilePath($base,$fullFilename)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <!-- Add .xml to the filename if it doesn't have it already.
         param filename is the filename, which may or may not include the extension in upper- or lowercase
         return a filename that will have an xml extension if the filename does not have one of the supported extensions -->
    <xsl:function name="nts:addXMLExtension" as="xs:string">
        <xsl:param name="filename" as="xs:string"/>
        <xsl:variable name="fullFilename" as="xs:string">
            <xsl:choose>
                <xsl:when test="ends-with(lower-case($filename), '.xml')">
                    <xsl:value-of select="$filename"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="concat($filename, '.xml')"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:value-of select="$fullFilename"/>
    </xsl:function>
    
    <!-- Construct a file path from the elements.
         param base is the folder where the file resides
         param filename is the name of the file in the folder including the extension
         return the full path to the file -->
    <xsl:function name="nts:constructFilePath" as="xs:string">
        <xsl:param name="base" as="xs:string" />
        <xsl:param name="filename" as="xs:string" />
        
        <xsl:variable name="separator">
            <xsl:choose>
                <xsl:when test="ends-with($base, '/')">
                    <xsl:value-of select="''"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="'/'"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:value-of select="string-join(($base, $filename), $separator)"/>
    </xsl:function>

    <!-- Add an origin or destination element.
         - type: either 'origin' or 'destination'
         - index: the origin.index or destination.index to set
         - isSUT: set the "SUT extension" by Interoplab to this value
    -->
    <xsl:function name="nts:addOriginOrDestination">
        <xsl:param name="type"  as="xs:string"/>
        <xsl:param name="index" as="xs:integer"/>
        <xsl:param name="isSUT" as="xs:boolean"/>
        
        <xsl:element name="{if ($type='origin') then 'origin' else 'destination'}">
            <extension url="http://fhir.interoplab.eu/fhir/StructureDefinition/Interoplab-CL-ext-SUT">
                <valueBoolean value="{$isSUT}"/>
            </extension>
            <index value="{$index}"/>
            <profile>
                <system value="{concat('http://terminology.hl7.org/CodeSystem/testscript-profile-', $type, '-types')}"/>
                <code value="{if ($type='origin') then 'FHIR-Client' else 'FHIR-Server'}"/>
            </profile>
        </xsl:element>
    </xsl:function>
    
    <xsl:function name="nts:_substring-before-last" as="xs:string">
        <xsl:param name="string1" as="xs:string"/>
        <xsl:param name="string2" as="xs:string"/>
        
        <xsl:variable name="parts" as="xs:string*">
            <xsl:if test="$string1 != '' and $string2 != ''">
                <xsl:variable name="head" select="substring-before($string1, $string2)" />
                <xsl:variable name="tail" select="substring-after($string1, $string2)" />
                <xsl:value-of select="$head" />
                <xsl:if test="contains($tail, $string2)">
                    <xsl:value-of select="$string2" />
                    <xsl:value-of select="nts:_substring-before-last($tail, $string2)"/>
                </xsl:if>
            </xsl:if>
        </xsl:variable>
        
        <xsl:value-of select="string-join($parts, '')"/>
    </xsl:function>
    
</xsl:stylesheet>