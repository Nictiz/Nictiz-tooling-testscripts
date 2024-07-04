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
    
    <!-- This file contains all the templates needed for the expand step. All templates here have mode "expand". -->

    <!-- Include the machinery to resolve auth tokens from a JSON file. This adds the parameter tokensJSONFile, which
         should hold an URL. -->
    <xsl:include href="resolveAuthTokens.xsl"/>
    
    <!-- Expand a nts:profile element to a FHIR profile element -->
    <xsl:template match="nts:profile" mode="expand">
        <profile id="{@id}">
            <reference value="{@value}"/>
        </profile>
    </xsl:template>
    
    <!-- Expand a nts:fixture element to a FHIR fixture element -->
    <xsl:template match="nts:fixture[@id and @href]" mode="expand">
        <xsl:param name="scenario" tunnel="yes"/>
        <xsl:param name="expectedResponseFormat" tunnel="yes"/>
        <xsl:param name="referenceBase" tunnel="yes"/>
        
        <xsl:variable name="href">
            <xsl:choose>
                <xsl:when test="$scenario = 'client' and contains(@href, '{$_FORMAT}')">
                    <xsl:message terminate="yes" select="'The use of parameter ''{$_FORMAT}'' has no meaning when the nts:scenario is ''client'''"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="replace(@href, '\{\$_FORMAT\}', $expectedResponseFormat)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <fixture id="{@id}">
            <autocreate value="false"/>
            <autodelete value="false"/>
            <resource>
                <reference value="{nts:constructFilePath($referenceBase, $href)}"/>
            </resource>
        </fixture>
    </xsl:template>
    
    <!-- Handle the magic parameter $_FORMAT in contentType -->
    <xsl:template match="f:contentType/@value" mode="expand">
        <xsl:param name="scenario" tunnel="yes"/>
        <xsl:param name="expectedResponseFormat" tunnel="yes"/>

        <xsl:choose>
            <xsl:when test="$scenario = 'client' and contains(., '{$_FORMAT}')">
                <xsl:message terminate="yes" select="'The use of parameter ''{$_FORMAT}'' has no meaning when the nts:scenario is ''client'''"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:attribute name="value">
                    <xsl:value-of select="replace(., '\{\$_FORMAT\}', $expectedResponseFormat)"/>
                </xsl:attribute>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <!-- Expand an nts:authToken element. For server scripts, this will result in a variable with a default value which
         the tester can override. For client scripts, this doesn't result in any output (but the element is used 
         beforehand for finding the correct authorization token to use. -->
    <xsl:template match="nts:authToken[@patientResourceId]" mode="expand">
        <xsl:param name="scenario" tunnel="yes"/>
        <xsl:param name="authTokens" tunnel="yes"/>
        
        <xsl:if test="$scenario='server'">
            <variable>
                <name value="{if (.[@id]) then ./@id else 'patient-token-id'}"/>
                <defaultValue value="{$authTokens[@id = ./@id]/@token}"/>
                <description value="OAuth Token for current patient"/>
            </variable>
        </xsl:if>
    </xsl:template>
    
    <!-- Expand an nts:patientTokenFixture element to create a variable called 'patient-token-id'. How this is handled
         is different for server and client scripts:
         - for a server script, it will be provided with a default value read from the fixture, which can be overridden
           by the TestScript executor.
         - for a client script, the fixture will be included as TestScript fixture and the variable will be read from
           it using a FHIRPath experssion. --> 
    <xsl:template match="nts:patientTokenFixture" mode="expand">
        <xsl:param name="scenario" tunnel="yes"/>
        <xsl:param name="basePath" tunnel="yes"/>
        <xsl:param name="referenceBase" tunnel="yes"/>
        
        <xsl:variable name="href" as="xs:string">
            <xsl:apply-templates select="@href" mode="expand"/>
        </xsl:variable>
                    
        <xsl:choose>
            <!-- Expand the nts:patientTokenFixture element for 'phr' type scripts -->
            <xsl:when test="$scenario='client'">
                <fixture id="patient-token-fixture">
                    <autocreate value="false"/>
                    <autodelete value="false"/>
                    <resource>
                        <reference value="{nts:constructFilePath($referenceBase, $href)}"/>
                    </resource>
                </fixture>
                <variable>
                    <name value="patient-token-id"/>
                    <expression value="Patient.id"/>
                    <sourceId value="patient-token-fixture"/>
                </variable>
            </xsl:when>
            <!-- Expand the nts:patientTokenFixture element for 'xis' type scripts -->
            <xsl:when test="$scenario='server'">
                <xsl:variable name="patientTokenFixture">
                    <xsl:copy-of select="document(string-join(($basePath,$referenceBase, $href), '/'),.)"/>
                </xsl:variable>
                <variable>
                    <name value="patient-token-id"/>
                    <defaultValue value="{$patientTokenFixture/f:Patient/f:id/@value}"/>
                    <xsl:if test="not($patientTokenFixture/f:Patient/f:id/@value)">
                        <xsl:comment>patientTokenFixture <xsl:value-of select="string-join(($referenceBase, $href), '/')"/> not available</xsl:comment>
                    </xsl:if>
                    <description value="OAuth Token for current patient"/>
                </variable>
            </xsl:when>
        </xsl:choose>
    </xsl:template>
    
    <!-- Expand the nts:includeDateT element -->
    <xsl:template match="nts:includeDateT" mode="expand">
        <xsl:variable name="value" as="xs:string">
            <xsl:apply-templates select="@value" mode="expand"/>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="$value = 'yes'">
                <variable>
                    <name value="T"/>
                    <defaultValue value="${{CURRENTDATE}}"/>
                    <description value="Date that data and queries are expected to be relative to."/>
                </variable>
            </xsl:when>
            <xsl:otherwise/>
        </xsl:choose>
    </xsl:template>
    
    <!--
        Expand a nts:rule element that declares a rule (which should go to the header section of the TestScript).
        Note: it is possible to use a single nts:rule element both for declaring and using a rule, hence this template
        matches first by setting a high priority and subsequently calls the 'use' template. A side effect that a 'use'
        output will be produced in the place where only a declaration is required, but this will be filtered out in the
        filter step.
    -->
    <xsl:template match="nts:rule[@id and @href]" mode="expand" priority="2">
        <xsl:param name="referenceBase" tunnel="yes"/>
        <!-- https://touchstone.aegis.net/touchstone/userguide/html/testscript-authoring/rule-authoring/basics.html -->
        <extension url="http://touchstone.aegis.net/touchstone/fhir/testing/StructureDefinition/testscript-rule">
            <extension url="ruleId">
                <valueId value="{@id}"/>
            </extension>
            <extension url="path">
                <valueString value="{nts:constructFilePath($referenceBase, @href)}"/>
            </extension>
        </extension>
        <xsl:next-match/>
    </xsl:template>

    <!--
        Expand a nts:rule element that uses a rule (in an assert).
        Note: it is possible to use a single nts:rule element both for declaring and using a rule, hence this template
        matches first by setting a high priority and subsequently calls the 'use' template,
    -->
    <xsl:template match="nts:rule[@id]" mode="expand">
        <xsl:variable name="expandedRule">
            <extension url="http://touchstone.aegis.net/touchstone/fhir/testing/StructureDefinition/testscript-assert-rule">
                <extension url="ruleId">
                    <valueId value="{@id}"/>
                </extension>
                <xsl:for-each select="./@*[not(local-name() = ('id', 'href'))]">
                    <extension url="param">
                        <extension url="name">
                            <valueString value="{local-name()}"/>
                        </extension>
                        <extension url="value">
                            <valueString value="{.}"/>
                        </extension>
                    </extension>
                </xsl:for-each>
                <xsl:apply-templates mode="expand" select="./nts:with-parameter"/>
                <xsl:apply-templates mode="expand" select="./nts:output"/>
            </extension>
        </xsl:variable>

        <xsl:apply-templates select="$expandedRule/(element()|comment())" mode="expand"/>
    </xsl:template>
    
    <!-- 
        Helper template to handle an nts:with-parameter element in nts:rule.
    -->
    <xsl:template match="nts:with-parameter[parent::nts:rule][@name and @value]" mode="expand">
        <extension url="param">
            <extension url="name">
                <valueString value="{./@name}"/>
            </extension>
            <extension url="value">
                <valueString value="{./@value}"/>
            </extension>
        </extension>
    </xsl:template>

    <!-- 
        Helper template to handle an nts:output element in nts:rule.
    -->
    <xsl:template match="nts:output[parent::nts:rule]" mode="expand">
        <xsl:param name="scenario" tunnel="yes"/>
        <xsl:param name="expectedResponseFormat" tunnel="yes"/>

        <extension url="output">
            <extension url="name">
                <valueString value="{./@name}"/>
            </extension>
            <xsl:if test="./@type">
                <extension url="type">
                    <valueString value="{./@type}"/>
                </extension>
            </xsl:if>
            <xsl:if test="./@contentType">
                <xsl:variable name="contentType">
                    <xsl:choose>
                        <xsl:when test="$scenario = 'client' and contains(./@contentType, '{$_FORMAT}')">
                            <xsl:message terminate="yes" select="'The use of parameter ''{$_FORMAT}'' has no meaning when the nts:scenario is ''client'''"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="replace(./@contentType, '\{\$_FORMAT\}', $expectedResponseFormat)"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <extension url="contentType">
                    <valueString value="{$contentType}"/>
                </extension>
            </xsl:if>
        </extension>
    </xsl:template>
    
    <!-- Default template in the expand mode -->
    <xsl:template match="node()|@*" mode="expand">
        <xsl:copy>
            <xsl:apply-templates select="node()|@*" mode="expand"/>
        </xsl:copy>
    </xsl:template>
    
</xsl:stylesheet>