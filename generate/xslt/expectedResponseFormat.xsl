<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0"
    xmlns="http://hl7.org/fhir"
    xmlns:f="http://hl7.org/fhir"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:nts="http://nictiz.nl/xsl/testscript"
    exclude-result-prefixes="#all">
    
    <!--<xsl:param name="expectedResponseFormat" required="yes"/>-->
    <xsl:param name="expectedResponseFormat" select="'xml'"/>
    
    <xsl:template match="node()|@*">
        <xsl:copy>
            <xsl:apply-templates select="node()|@*"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="@value[contains(.,'${expectedResponseFormat}')]">
        <xsl:variable name="upper">
            <xsl:choose>
                <xsl:when test="parent::f:name/parent::f:TestScript">
                    <xsl:value-of select="true()"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="false()"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:analyze-string select="." regex="[$][{{]expectedResponseFormat[}}]">
            <xsl:matching-substring>
                <xsl:choose>
                    <xsl:when test="$upper=true()">
                        <xsl:value-of select="upper-case($expectedResponseFormat)"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="lower-case($expectedResponseFormat)"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:matching-substring>
            <xsl:non-matching-substring>
                <xsl:value-of select="."/>
            </xsl:non-matching-substring>
        </xsl:analyze-string>
    </xsl:template>
    
</xsl:stylesheet>