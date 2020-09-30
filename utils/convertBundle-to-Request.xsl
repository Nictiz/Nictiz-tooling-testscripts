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
    
    <xsl:template match="f:Bundle/f:meta"/>
    <xsl:template match="f:Bundle/f:type/@value">
        <xsl:attribute name="value">batch</xsl:attribute>
    </xsl:template>
    <xsl:template match="f:Bundle/f:total"/>
    <xsl:template match="f:Bundle/f:link"/>
    
    <xsl:template match="f:Bundle/f:entry/f:search">
        <request>
            <method value="POST"/>
            <url value="{parent::f:entry/f:resource/f:*/local-name()}"/>
        </request>
    </xsl:template>
    
</xsl:stylesheet>