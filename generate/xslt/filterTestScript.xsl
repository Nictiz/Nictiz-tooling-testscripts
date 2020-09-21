<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0"
    xmlns="http://hl7.org/fhir"
    xmlns:f="http://hl7.org/fhir"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:nts="http://nictiz.nl/xsl/testscript"
    exclude-result-prefixes="#all">
    <xsl:output method="xml" indent="yes"/>
    <xsl:strip-space elements="*"/>
    
    <xsl:template match="f:TestScript">
        
        <!-- Expand all the Nictiz inclusion elements to their FHIR representation --> 
        <xsl:variable name="expanded">
            <xsl:copy-of select="."/>
        </xsl:variable>
        
        <!-- Filter the expanded TestScript. This will add the required elements and put everything in the right
             position --> 
        <xsl:apply-templates mode="filter" select="$expanded">
            <xsl:with-param name="fixtures" select="$expanded//f:fixture" tunnel="yes"/>
            <xsl:with-param name="profiles" select="$expanded//f:profile[not(ancestor::f:origin | ancestor::f:destination)]" tunnel="yes"/>
            <xsl:with-param name="variables" select="$expanded//f:variable" tunnel="yes"/>
            <xsl:with-param name="rules" select="$expanded//f:rule[@id]" tunnel="yes"/>
        </xsl:apply-templates>
    </xsl:template>
    
    <!-- Silence status, fixture, profile, variable and rule elements, because they are already handled elsewhere -->
    <xsl:template match="f:TestScript//f:fixture" mode="filter" />
    <xsl:template match="f:TestScript//f:profile[not(ancestor::f:origin | ancestor::f:destination)]" mode="filter" />
    <xsl:template match="f:TestScript//f:variable" mode="filter" />
    <xsl:template match="f:TestScript//f:rule[@id]" mode="filter" />

    <!-- Silence all remaining nts: elements and attributes (that have been read but are not transformed) -->
    <xsl:template match="nts:*" mode="filter">
        <xsl:apply-templates select="node()" mode="#current"/>
    </xsl:template>
    <xsl:template match="@nts:*" mode="filter"/>
    
    <!-- Use the setup or (if absent) first test as a hook to inject the fixture, profile, variable and rule elements -->  
    <xsl:template match="f:TestScript/f:setup | f:TestScript/f:test[not(preceding-sibling::f:setup) and not(preceding-sibling::f:test)]" mode="filter">
        <xsl:param name="fixtures" tunnel="yes"/>
        <xsl:param name="profiles" tunnel="yes"/>
        <xsl:param name="variables" tunnel="yes"/>
        <xsl:param name="rules" tunnel="yes"/>

        <xsl:for-each-group select="$fixtures" group-by="@id">
            <xsl:for-each select="subsequence(current-group(), 2)">
                <xsl:if test="not(deep-equal(current-group()[1], .))">
                    <xsl:message terminate="yes" select="concat('Encountered different fixture inclusions using the same id ''', @id, '''')"/>
                </xsl:if>
            </xsl:for-each>
            <xsl:copy-of select="current-group()[1]"/>
        </xsl:for-each-group>
        <xsl:for-each-group select="$profiles" group-by="@id">
            <xsl:for-each select="subsequence(current-group(), 2)">
                <xsl:if test="not(deep-equal(current-group()[1], .))">
                    <xsl:message terminate="yes" select="concat('Encountered different profile declarations using the id ''', @id, '''')"/>
                </xsl:if>
            </xsl:for-each>
            <xsl:copy-of select="current-group()[1]"/>
        </xsl:for-each-group>
        <xsl:for-each-group select="$variables" group-by="f:name/@value">
            <xsl:for-each select="subsequence(current-group(), 2)">
                <xsl:if test="not(deep-equal(current-group()[1], .))">
                    <xsl:message terminate="yes" select="concat('Encountered different variables using the name ''', f:name/@value, '''')"/>
                </xsl:if>
            </xsl:for-each>
            <xsl:copy-of select="current-group()[1]"/>
        </xsl:for-each-group>
        <xsl:for-each-group select="$rules" group-by="@id">
            <xsl:for-each select="subsequence(current-group(), 2)">
                <xsl:if test="not(deep-equal(current-group()[1], .))">
                    <xsl:message terminate="yes" select="concat('Encountered different rules using the id ''', @id, '''')"/>
                </xsl:if>
            </xsl:for-each>
            <xsl:copy-of select="current-group()[1]"/>
        </xsl:for-each-group>
        
        <!-- Write back the element we matched on -->
        <xsl:copy>
            <xsl:apply-templates select="@*" mode="#current"/>
            <xsl:apply-templates select="./(*|comment())" mode="filter"/>
        </xsl:copy>
    </xsl:template>

    <!-- Default template in the filter mode -->
    <xsl:template match="@*|node()" mode="filter">
        <xsl:copy>
            <xsl:apply-templates select="@*|node()" mode="filter"/>
        </xsl:copy>
    </xsl:template>
    
</xsl:stylesheet>