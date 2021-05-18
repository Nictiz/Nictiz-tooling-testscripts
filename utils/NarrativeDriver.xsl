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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:f="http://hl7.org/fhir" xmlns:xhtml="http://www.w3.org/1999/xhtml" xmlns:util="urn:hl7:utilities" version="2.0" exclude-result-prefixes="#all" xmlns:saxon="http://saxon.sf.net/">
    
    <!-- NarrativeGenerator from c46e3c597d90c532fbd4595784292253a5d8a925 (2021-04-29) last used -->
    <xsl:import href="../../HL7-mappings/ada_2_fhir/fhir/NarrativeGenerator.xsl"/>
    <xsl:param name="override" select="'true'"/>
    <xsl:param name="util:textlangDefault" select="'nl-nl'"/>
    
    <!-- Uncomment if you want to test this transform directly -->
    <xsl:output omit-xml-declaration="yes" indent="yes" xml:space="preserve"/>
    <xsl:template match="/">
        <xsl:for-each select="collection('file:/C:/Users/144189-ADM/Documents/Git/Nictiz-STU3-testscripts-src/src?select=*.xml;recurse=yes')">
            <!-- Could not achieve what I wanted with glob pattern, so some selection is done here -->
            <xsl:choose>
                <!-- Only files in '_reference' (sub)folders -->
                <xsl:when test="not(contains(document-uri(.),'_reference'))"/>
                <!-- Exclude patient tokens by file name convention -->
                <xsl:when test="contains(document-uri(.),'-token.xml')"/>
                <!-- Exclude minimumId fixtures by (implicit?) file name convention -->
                <xsl:when test="contains(document-uri(.),'-minimum.xml')"/>
                <!-- Exclude Medication and AllergyIntolerance - Narrative is added/updated in separate process -->
                <xsl:when test="contains(document-uri(.),'Medication-9-0-7')"/>
                <xsl:when test="contains(document-uri(.),'AllergyIntolerance-3-0')"/>
                <!-- Added saxon:line-length and using Saxon-PE 9.9.1.7 in Oxygen to remove unwanted changes in schema declarations -->
                <xsl:otherwise>
                    <xsl:result-document href="{document-uri(.)}" saxon:line-length="1000">
                        <xsl:apply-templates mode="addNarrative"/>
                    </xsl:result-document>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:template>
    
</xsl:stylesheet>
