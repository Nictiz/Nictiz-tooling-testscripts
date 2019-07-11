<?xml version="1.0" encoding="UTF-8"?>
<!--
Copyright © Nictiz

This program is free software; you can redistribute it and/or modify it under the terms of the
GNU Lesser General Public License as published by the Free Software Foundation; either version
2.1 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU Lesser General Public License for more details.

The full text of the license is available at http://www.gnu.org/copyleft/lesser.html
-->
<xsl:stylesheet exclude-result-prefixes="#all" xmlns:nf="http://www.nictiz.nl/functions" xmlns:f="http://hl7.org/fhir" xmlns:local="urn:fhir:stu3:functions" xmlns="http://hl7.org/fhir" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0">
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p><xd:b>Author:</xd:b> Nictiz</xd:p>
            <xd:p><xd:b>Purpose:</xd:b> This XSL was created to facilitate mapping from ADA BundleOfEpisode-transaction, to HL7 FHIR STU3 profiles <xd:a href="https://simplifier.net/resolve?target=simplifier&amp;canonical=http://nictiz.nl/fhir/StructureDefinition/nl-core-episodeofcare">http://nictiz.nl/fhir/StructureDefinition/nl-core-episodeofcare</xd:a>.</xd:p>
            <xd:p>
                <xd:b>History:</xd:b>
                <xd:ul>
                    <xd:li>2018-10-10 version 0.1 <xd:ul><xd:li>Initial version</xd:li></xd:ul></xd:li>
                </xd:ul>
            </xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:output method="xml" indent="yes" omit-xml-declaration="yes"/>
    <xsl:strip-space elements="*"/>
    <xsl:include href="../../../2_fhir_ketenzorg_include.xsl"/>
    
    <!-- parameter to determine whether to refer bij resource/id -->
    <!-- should be false when there is no FHIR server available to retrieve the resources -->
    <xsl:param name="referByIdOverride" as="xs:boolean" select="false()"/>

    <xsl:variable name="usecase">episode</xsl:variable>
    <xsl:variable name="commonEntries" as="element(f:entry)*">
        <xsl:copy-of select="$patients//f:entry | $practitioners/f:entry | $organizations/f:entry | $practitionerRoles/f:entry | $products/f:entry | $locations/f:entry | $body-observations/f:entry | $prescribe-reasons/f:entry"/>
    </xsl:variable>
    
    <xd:doc>
        <xd:desc>Start conversion. Handle interaction specific stuff for "beschikbaarstellen episode".</xd:desc>
    </xd:doc>
    <xsl:template match="/">
        <xsl:call-template name="BundleOfEpisodes"/>
    </xsl:template>
    <xd:doc>
        <xd:desc>Build a FHIR Bundle of type searchset or in case of $referByIdOverride = true(), build individual files.</xd:desc>
    </xd:doc>
    <xsl:template name="BundleOfEpisodes">
        <xsl:variable name="entries" as="element(f:entry)*">
            <xsl:copy-of select="$bouwstenen"/>
            <!-- common entries (patient, practitioners, organizations, practitionerroles, products, locations, gewichten, lengtes, reden van voorschrijven,  bouwstenen -->
            <xsl:if test="$bouwstenen"><xsl:copy-of select="$commonEntries"/></xsl:if>
        </xsl:variable>
        
        <xsl:choose>
            <xsl:when test="$referByIdOverride = true()">
                <xsl:apply-templates select="$entries//f:resource/*" mode="doResourceInResultdoc"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:processing-instruction name="xml-model">href="http://hl7.org/fhir/STU3/bundle.sch" type="application/xml" schematypens="http://purl.oclc.org/dsdl/schematron"</xsl:processing-instruction>
                <Bundle xsl:exclude-result-prefixes="#all" xmlns="http://hl7.org/fhir" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://hl7.org/fhir http://hl7.org/fhir/STU3/fhir-all.xsd">
                    <type value="searchset"/>
                    <total value="{count($bouwstenen)}"/>
                    <xsl:copy-of select="$entries"/>
                </Bundle>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xd:doc>
        <xd:desc/>
    </xd:doc>
    <xsl:template match="f:resource/*" mode="doResourceInResultdoc">
        <xsl:variable name="zib-name" select="tokenize(f:meta/f:profile/@value, '/')[last()]"/>
        <xsl:result-document href="../fhir_instance/{$usecase}-{$zib-name}-{ancestor::f:entry/f:fullUrl/tokenize(@value, '[/:]')[last()]}.xml">
            <xsl:processing-instruction name="xml-model">href="http://hl7.org/fhir/STU3/<xsl:value-of select="lower-case(local-name())"/>.sch" type="application/xml" schematypens="http://purl.oclc.org/dsdl/schematron"</xsl:processing-instruction>
            <xsl:copy>
                <xsl:copy-of select="@*"/>
                <xsl:attribute name="xsi:schemaLocation">http://hl7.org/fhir http://hl7.org/fhir/STU3/fhir-all.xsd</xsl:attribute>
                <xsl:copy-of select="node()"/>
            </xsl:copy>
        </xsl:result-document>
    </xsl:template>
</xsl:stylesheet>