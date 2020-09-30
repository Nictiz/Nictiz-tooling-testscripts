<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns="http://hl7.org/fhir"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:nts="http://nictiz.nl/xsl/testscript"
    xmlns:f="http://hl7.org/fhir"
    xmlns:nf="http://www.nictiz.nl/functions"
    exclude-result-prefixes="#all"
    version="2.0">
    
    <xsl:template match="node()|@*" mode="#all">
        <xsl:copy>
            <xsl:apply-templates select="node()|@*" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    
    <!-- TO DO in Bundles that you will send:
    (- Remove resource.id)
    - Remove entry.search
    - Add entry.request:
    <request>
         <method value="POST"/>
         <url value="Patient"/>
    </request>
    -->
    
    <xsl:template match="f:destination">
        <xsl:copy>
            <xsl:apply-templates select="node()|@*" mode="#current"/>
        </xsl:copy>
        <fixture id="test-request">
            <resource>
                <reference value="./_request-body/medmij-gpdata-xis-1-1-serve-all-allergyintolerance-xml.xml"/>
            </resource>
        </fixture>
    </xsl:template>
    
    <xsl:template match="f:action/f:operation/f:type/f:code/@value">
        <!--<xsl:choose>
            <xsl:when test="parent::f:code/parent::f:type/following-sibling::f:resource">
                <xsl:attribute name="value">create</xsl:attribute>
            </xsl:when>
            <xsl:otherwise>-->
                <xsl:attribute name="value">batch</xsl:attribute>
            <!--</xsl:otherwise>
        </xsl:choose>-->
    </xsl:template>
    
    <xsl:template match="f:action/f:operation/f:resource"/>
    <xsl:template match="f:action/f:operation/f:params"/>
    
    <xsl:template match="f:action/f:operation/f:responseId">
        <requestId value="{@value}"/>
        <sourceId value="test-request"/>
    </xsl:template>
    
    <xsl:template match="f:action/f:assert[f:warningOnly or matches(f:expression/@value,'[$][{][A-Za-z0-9-]*[}]')]/f:direction/@value">
        <xsl:attribute name="value">request</xsl:attribute>
    </xsl:template>
    
    <xsl:template match="f:action[f:assert[f:operator/@value='equals' and f:value/@value='searchset']]"/>
    <xsl:template match="f:action[f:assert/f:expression/@value='Bundle.total.toInteger() &lt;= Bundle.entry.where(search.empty() or search.mode = ''match'').count()']"/>
    <xsl:template match="f:action[f:assert/f:expression/@value='Bundle.link.relation.exists() and Bundle.link.relation = ''self'' and Bundle.link.url.exists()']"/>
    
</xsl:stylesheet>