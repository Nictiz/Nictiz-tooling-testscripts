<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0"
    xmlns="http://hl7.org/fhir"
    xmlns:f="http://hl7.org/fhir"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:nts="http://nictiz.nl/xsl/testscript"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:uuid="http://www.uuid.org"
    exclude-result-prefixes="#all">
    
    <xsl:import href="https://github.com/Nictiz/HL7-mappings/raw/faf8e311d8870144ff151cd94cf19b96859913c7/util/uuid.xsl"/>
    
    <xsl:output method="xml" indent="yes"/>
    <xsl:strip-space elements="*"/>
    
    <!-- Checks fixtures for the nts:includeFixture element to include fixtures in other fixtures. If this element is applied in batch or transaction Bundles, Resource.id is removed and (after all fixtures are included) fullUrl and references are rewritten -->
    
    <!-- The absolute path to the folder of fixtures -->
    <xsl:param name="referenceDir"/>
    
    <!-- Convert the reference to a file:// URL and make sure it ends with a slash. -->
    <xsl:variable name="referenceDirAsUrl">
        <xsl:variable name="fileUrl">
            <xsl:choose>
                <xsl:when test="starts-with($referenceDir, 'file:')">
                    <xsl:value-of select="$referenceDir"/>
                </xsl:when>
                <xsl:when test="starts-with($referenceDir,'/')">
                    <!-- Unix style -->
                    <xsl:value-of select="concat('file:', translate($referenceDir,'\','/'))"/>
                </xsl:when>
                <xsl:when test="matches($referenceDir,'^[A-Za-z]:[/\\]')">
                    <!-- Windows style -->
                    <xsl:value-of select="concat('file:/',translate($referenceDir,'\','/'))"/>
                </xsl:when>
            </xsl:choose>
        </xsl:variable>
        <!-- escape-html-uri is better suited then encode-uri, but spaces are left so they are handled separately -->
        <xsl:value-of select="replace(escape-html-uri(if (ends-with($fileUrl, '/')) then $fileUrl else concat($fileUrl, '/')), ' ', '%20')"/>
    </xsl:variable>
    
    <xsl:template match="node()|@*" mode="#all">
        <xsl:copy copy-namespaces="no">
            <xsl:apply-templates select="node()|@*" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="/">
        <xsl:variable name="bundleType">
            <xsl:choose>
                <xsl:when test="f:Bundle/f:type[@value]">
                    <xsl:value-of select="f:Bundle/f:type/@value"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:text>null</xsl:text>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:choose>
            <xsl:when test=".//nts:includeFixture">
                <xsl:variable name="resolvedFixture">
                    <xsl:apply-templates select="*" mode="resolve"/>
                </xsl:variable>
                
                <xsl:choose>
                    <xsl:when test="$bundleType = ('batch', 'transaction')">
                        <xsl:apply-templates select="$resolvedFixture" mode="rewrite">
                            <xsl:with-param name="bundleType" tunnel="yes"/>
                        </xsl:apply-templates>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:copy-of select="$resolvedFixture"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy-of select="*"/>
            </xsl:otherwise>
        </xsl:choose>
        
    </xsl:template>
    
    <xsl:template match="nts:includeFixture" mode="resolve">
        <xsl:variable name="docUri" select="concat($referenceDirAsUrl,@href)"/>
        <xsl:choose>
            <xsl:when test="doc-available($docUri)">
                <xsl:apply-templates select="doc($docUri)" mode="#current"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:message>includeFixture "<xsl:value-of select="$docUri"/>" not valid or unavailable</xsl:message>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <!-- Rewrite fullUrl or add it if it is not there-->
    <xsl:template match="f:Bundle/f:entry" mode="rewrite">
        <xsl:copy>
            <xsl:apply-templates select="f:link" mode="#current"/>
            <fullUrl value="{concat('urn:uuid:', uuid:get-uuid(.))}"/>
            <xsl:apply-templates select="f:*[not(self::f:link) and not(self::f:fullUrl)]" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    
    <!-- Remove id as it throws warnings in the validator -->
    <xsl:template match="f:Bundle/f:entry/f:resource/f:*/f:id" mode="rewrite"/>
    
    <!-- Rewrite references -->
    <xsl:template match="f:Bundle/f:entry/f:resource/f:*//f:reference/@value" mode="rewrite">
        <xsl:param name="bundleType" tunnel="yes"/>
        <xsl:variable name="referencedId" select="substring-after(., '/')"/>
        <xsl:choose>
            <!-- if literal reference that matches a resource in the Bundle -->
            <xsl:when test="ancestor::f:Bundle/f:entry/f:resource/f:*/f:id/@value = $referencedId">
                <xsl:if test="$bundleType = 'batch'">
                    <xsl:message>Warning: rewriting internal reference in batch Bundle. Strictly this is illegal, but is a known issue in MedMij STU3 SelfMeasurements implementation</xsl:message>
                </xsl:if>
                <xsl:attribute name="value" select="concat('urn:uuid:', uuid:get-uuid(ancestor::f:Bundle/f:entry[f:resource/f:*/f:id/@value = $referencedId][1]))"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:next-match/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <!-- Remove stuff that sometimes is present at the top of a resource -->
    <xsl:template match="processing-instruction()" mode="#all" priority="1"/>
    <xsl:template match="@xsi:schemaLocation" mode="#all"/>
    
    <!-- Overrule imported functions to output a stable uuid -->
    <xsl:function name="uuid:generate-timestamp">
        <xsl:param name="node"/>
        <!-- date calculation automatically goes correct when you add the timezone information, in this case that is UTC. -->
        <xsl:variable name="duration-from-1582" as="xs:dayTimeDuration">
            <!-- fixed date for stable uuid for test purposes -->
            <xsl:sequence select="xs:dateTime('2022-01-01T00:00:00.000Z') - xs:dateTime('1582-10-15T00:00:00.000Z')"/>
        </xsl:variable>
        <xsl:variable name="random-offset" as="xs:integer">
            <xsl:sequence select="uuid:next-nr($node) mod 10000"/>
        </xsl:variable>
        <!-- do the math to get the 100 nano second intervals -->
        <xsl:sequence select="(days-from-duration($duration-from-1582) * 24 * 60 * 60 + hours-from-duration($duration-from-1582) * 60 * 60 + minutes-from-duration($duration-from-1582) * 60 + seconds-from-duration($duration-from-1582)) * 1000 * 10000 + $random-offset"/>
    </xsl:function>
    
    <xsl:function name="uuid:generate-clock-id" as="xs:string">
        <xsl:sequence select="'0000'"/>
    </xsl:function>
    
</xsl:stylesheet>