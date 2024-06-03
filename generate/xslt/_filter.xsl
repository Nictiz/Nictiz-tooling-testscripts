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
        This file contains all the templates needed for the filtering step. All templates here have mode "filter".
        It expects the following global parameters to be set:
        - versionAddition
    -->

    <!-- Match the root to organize and/or edit all children -->
    <xsl:template match="f:TestScript" mode="filter">
        <xsl:param name="target" tunnel="yes"/>
        <xsl:param name="scenario" tunnel="yes"/>
        <xsl:param name="expectedResponseFormat" tunnel="yes"/>
        <xsl:param name="fixtures" tunnel="yes"/>
        <xsl:param name="profiles" tunnel="yes"/>
        <xsl:param name="variables" tunnel="yes"/>
        <xsl:param name="rules" tunnel="yes"/>
        
        <xsl:variable name="url">
            <xsl:text>http://nictiz.nl/fhir/TestScript/</xsl:text>
            <xsl:value-of select="f:id/@value"/>
            <xsl:if test="not($target = '#default')">
                <xsl:text>-</xsl:text>
                <xsl:value-of select="$target"/>
            </xsl:if>
            <xsl:if test="$scenario='server'">
                <xsl:text>-</xsl:text>
                <xsl:value-of select="$expectedResponseFormat"/>
            </xsl:if>
        </xsl:variable>
                
        <xsl:copy>
            <xsl:apply-templates select="f:id" mode="#current"/>
            <xsl:if test="f:meta/f:profile/@value">
                <xsl:message>Overriding meta.profile to Aegis TestScript profile</xsl:message>
            </xsl:if>
            <meta>
                <xsl:apply-templates select="f:meta/f:versionId | f:meta/f:lastUpdated" mode="#current"/>
                <profile value="http://touchstone.aegis.net/touchstone/fhir/testing/StructureDefinition/testscript"/>
                <xsl:apply-templates select="f:meta/f:security | f:meta/f:tag" mode="#current"/>
            </meta>
            <!-- Apply all templates that can exist between f:meta and f:url -->
            <xsl:apply-templates select="f:implicitRules | f:language | f:text | f:contained" mode="#current"/>
            
            <xsl:for-each-group select="$rules" group-by="f:extension[@url = 'ruleId']/f:valueId/@value">
                <xsl:for-each select="subsequence(current-group(), 2)">
                    <xsl:if test="not(deep-equal(current-group()[1], .))">
                        <xsl:message terminate="yes" select="concat('Encountered different rules using the id ''', f:extension[@url = 'ruleId']/f:valueId/@value, '''')"/>
                    </xsl:if>
                </xsl:for-each>
                <xsl:apply-templates select="current-group()[1]" mode="filter">
                    <xsl:with-param name="doCopy" select="true()"/>
                </xsl:apply-templates>
            </xsl:for-each-group>
            
            <xsl:apply-templates select="f:extension[not(@url = 'http://touchstone.aegis.net/touchstone/fhir/testing/StructureDefinition/testscript-rule')] | f:modifierExtension" mode="#current"/>
            <xsl:if test="f:url/@value">
                <xsl:message>Overriding url to conform to convention</xsl:message>
            </xsl:if>
            <url value="{$url}"/>
            <!-- Always add version -->
            <xsl:choose>
                <xsl:when test="normalize-space($versionAddition)">
                    <version value="{concat(f:version/@value, $versionAddition)}"/>
                </xsl:when>
                <xsl:when test="f:version[@value]">
                    <xsl:copy-of select="f:version"/>                    
                </xsl:when>
            </xsl:choose>
            <xsl:apply-templates select="f:name | f:title" mode="#current"/>
            <xsl:choose>
                <xsl:when test="f:status">
                    <xsl:apply-templates select="f:status"/>
                </xsl:when>
                <xsl:otherwise>
                    <status value="active"/>
                </xsl:otherwise>
            </xsl:choose>
            <xsl:if test="f:publisher/@value">
                <xsl:message>Overriding publisher to 'Nictiz'</xsl:message>
            </xsl:if>
            <publisher value="Nictiz"/>
            <xsl:if test="f:contact/@value">
                <xsl:message>Overriding contact to 'Nictiz'</xsl:message>
            </xsl:if>
            <contact>
                <name value="Nictiz"/>
                <telecom>
                    <system value="email"/>
                    <value value="kwalificatie@nictiz.nl"/>
                    <use value="work"/>
                </telecom>
            </contact>
            <xsl:apply-templates select="f:description | f:useContext | f:jurisdiction | f:purpose | f:copyright" mode="#current"/>

            <!-- Include origin and destination elements -->
            <xsl:copy-of select="nts:addOrigins(1, if (./@nts:numOrigins) then ./@nts:numOrigins else 1)"/>
            <xsl:copy-of select="nts:addDestinations(1, if (./@nts:numDestinations) then ./@nts:numDestinations else 1)"/>

            <xsl:apply-templates select="f:metadata" mode="#current"/>
            <xsl:for-each-group select="$fixtures" group-by="@id">
                <xsl:for-each select="subsequence(current-group(), 2)">
                    <xsl:if test="not(deep-equal(current-group()[1], .))">
                        <xsl:message terminate="yes" select="concat('Encountered different fixture inclusions using the same id ''', @id, '''')"/>
                    </xsl:if>
                </xsl:for-each>
                <xsl:apply-templates select="current-group()[1]" mode="filter">
                    <xsl:with-param name="doCopy" select="true()"/>
                </xsl:apply-templates>
            </xsl:for-each-group>
            <xsl:for-each-group select="$profiles" group-by="@id">
                <xsl:for-each select="subsequence(current-group(), 2)">
                    <xsl:if test="not(deep-equal(current-group()[1], .))">
                        <xsl:message terminate="yes" select="concat('Encountered different profile declarations using the id ''', @id, '''')"/>
                    </xsl:if>
                </xsl:for-each>
                <xsl:apply-templates select="current-group()[1]" mode="filter">
                    <xsl:with-param name="doCopy" select="true()"/>
                </xsl:apply-templates>
            </xsl:for-each-group>
            <xsl:for-each-group select="$variables" group-by="f:name/@value">
                <xsl:for-each select="subsequence(current-group(), 2)">
                    <xsl:if test="not(deep-equal(current-group()[1], .))">
                        <xsl:message terminate="yes" select="concat('Encountered different variables using the name ''', f:name/@value, '''')"/>
                    </xsl:if>
                </xsl:for-each>
                <xsl:apply-templates select="current-group()[1]" mode="filter">
                    <xsl:with-param name="doCopy" select="true()"/>
                </xsl:apply-templates>
            </xsl:for-each-group>
            <xsl:apply-templates select="f:setup | f:test | f:teardown" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    
    <!-- Fixture, profile, variable and rule elements:
        Silence by default, because they are already handled elsewhere, but copied if explicitly intended with param doCopy -->
    <xsl:template match="f:TestScript//f:fixture" mode="filter">
        <xsl:param name="doCopy" select="false()"/>
        <xsl:if test="$doCopy">
            <xsl:next-match/>
        </xsl:if>
    </xsl:template>
    <xsl:template match="f:TestScript//f:profile" mode="filter">
        <xsl:param name="doCopy" select="false()"/>
        <xsl:if test="$doCopy">
            <xsl:next-match/>
        </xsl:if>
    </xsl:template>
    <xsl:template match="f:TestScript//f:variable" mode="filter">
        <xsl:param name="doCopy" select="false()"/>
        <xsl:if test="$doCopy">
            <xsl:next-match/>
        </xsl:if>
    </xsl:template>
    <xsl:template match="f:TestScript//f:extension[@url = 'http://touchstone.aegis.net/touchstone/fhir/testing/StructureDefinition/testscript-rule']" mode="filter">
        <xsl:param name="doCopy" select="false()"/>
        <xsl:if test="$doCopy">
            <xsl:next-match/>
        </xsl:if>
    </xsl:template>
    
    <!-- Silence rule use elements that have been produced in the wrong place as a side effect of the declaration element --> 
    <xsl:template match="f:TestScript//f:extension[@url = 'http://touchstone.aegis.net/touchstone/fhir/testing/StructureDefinition/testscript-assert-rule'][not(parent::f:assert)]" mode="filter" />
    
    <!-- Silence all remaining nts: elements and attributes (that have been read but are not transformed) -->
    <xsl:template match="nts:*" mode="filter"/>
    <xsl:template match="@nts:*" mode="filter"/>
    
    <!-- Add the target and/or the format for requests to the TestScript id, if specified -->
    <xsl:template match="f:TestScript/f:id/@value" mode="filter">
        <xsl:param name="target" tunnel="yes"/>
        <xsl:param name="scenario" tunnel="yes"/>
        <xsl:param name="expectedResponseFormat" tunnel="yes"/>
        <xsl:variable name="joinedString">
            <xsl:value-of select="."/>
            <xsl:if test="not($target = '#default')">
                <xsl:text>-</xsl:text>
                <xsl:value-of select="$target"/>
            </xsl:if>
            <xsl:if test="$scenario='server' and not(ancestor::f:TestScript/f:test/f:action/f:operation/f:accept) and not(contains(lower-case(.),$expectedResponseFormat))">
                <xsl:text>-</xsl:text>
                <xsl:value-of select="lower-case($expectedResponseFormat)"/>
            </xsl:if>
        </xsl:variable>
        
        <xsl:attribute name="value">
            <xsl:choose>
                <xsl:when test="string-length($joinedString) gt 64">
                    <xsl:value-of select="substring($joinedString, string-length($joinedString) - 63)"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="$joinedString"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:attribute>
    </xsl:template>
    
    <!--Add the target and/or the format for requests to the TestScript name, if specified -->
    <xsl:template match="f:TestScript/f:name/@value" mode="filter">
        <xsl:param name="target" tunnel="yes"/>
        <xsl:param name="scenario" tunnel="yes"/>
        <xsl:param name="expectedResponseFormat" tunnel="yes"/>
        <xsl:attribute name="value">
            <xsl:value-of select="."/>
            <xsl:if test="not($target = '#default')">
                <xsl:text> - target </xsl:text>
                <xsl:value-of select="$target"/>
            </xsl:if>
            <xsl:if test="$scenario='server' and not(ancestor::f:TestScript/f:test/f:action/f:operation/f:accept) and not(contains(lower-case(.),$expectedResponseFormat))">
                <xsl:text> - </xsl:text>
                <xsl:value-of select="upper-case($expectedResponseFormat)"/>
                <xsl:text> Format</xsl:text>
            </xsl:if>
        </xsl:attribute>
    </xsl:template>
    
    <!--Add the Accept header and encodeRequestUrl, if necessary-->
    <xsl:template match="f:TestScript/f:test/f:action/f:operation" mode="filter">
        <xsl:param name="scenario" tunnel="yes"/>
        <xsl:param name="expectedResponseFormat" tunnel="yes"/>
        
        <!--All elements that can exist before the accept element following the FHIR spec.-->
        <xsl:variable name="pre-accept" select="('type','resource','label','description')"/>
        <xsl:variable name="pre-encodeRequestUrl" select="('contentType','destination','accept')"/>
        <xsl:copy>
            <xsl:apply-templates select="@*" mode="#current"/>
            <xsl:apply-templates select="f:*[local-name()=$pre-accept]" mode="#current"/>
            <xsl:if test="$scenario='server' and not(f:accept) and $expectedResponseFormat != ''">
                <accept value="{lower-case($expectedResponseFormat)}"/>
            </xsl:if>
            <xsl:apply-templates select="f:*[local-name()=$pre-encodeRequestUrl]" mode="#current"/>
            <xsl:if test="not(f:encodeRequestUrl)">
                <encodeRequestUrl value="true"/>
            </xsl:if>
            <xsl:apply-templates select="f:*[not(local-name()=$pre-accept or local-name()=$pre-encodeRequestUrl)]" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    
    <!--Add TouchStone assert-stopTestOnFail extension and warningOnly flag by default.-->
    <xsl:template match="f:TestScript/f:test/f:action/f:assert" mode="filter">
        <xsl:copy>
            <xsl:apply-templates select="@*" mode="#current"/>
            <xsl:choose>
                <xsl:when test="f:extension/@url = 'http://touchstone.aegis.net/touchstone/fhir/testing/StructureDefinition/testscript-assert-stopTestOnFail'"/>
                <xsl:when test="@nts:stopTestOnFail='true'">
                    <extension url="http://touchstone.aegis.net/touchstone/fhir/testing/StructureDefinition/testscript-assert-stopTestOnFail">
                        <valueBoolean value="true"/>
                    </extension>
                </xsl:when>
                <xsl:otherwise>
                    <extension url="http://touchstone.aegis.net/touchstone/fhir/testing/StructureDefinition/testscript-assert-stopTestOnFail">
                        <valueBoolean value="false"/>
                    </extension>
                </xsl:otherwise>
            </xsl:choose>
            <xsl:apply-templates select="node()" mode="#current"/>
            <xsl:if test="not(f:warningOnly)">
                <warningOnly value="false"/>
            </xsl:if>
        </xsl:copy>
    </xsl:template>
    
    <!--Remove unwanted space from FHIRPath expressions-->
    <xsl:template match="f:TestScript/f:test/f:action/f:assert/f:expression/@value" mode="filter">
        <xsl:attribute name="value">
            <xsl:value-of select="normalize-space(.)"/>
        </xsl:attribute>
    </xsl:template>

    <!-- Default template in the filter mode -->
    <xsl:template match="@*|node()" mode="filter">
        <xsl:copy>
            <xsl:apply-templates select="@*|node()" mode="filter"/>
        </xsl:copy>
    </xsl:template>
</xsl:stylesheet>