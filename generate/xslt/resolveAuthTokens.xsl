<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:nts="http://nictiz.nl/xsl/testscript"
    exclude-result-prefixes="xs"
    version="2.0">
    
    <!-- Helper template to resolve authorization tokens from a JSON file, given the id of the Patient resource. The
         two concepts are linked by placing them in the same group with the keys 'resourceId' and 'accessToken'. This
         is a structure imposed by Touchstone for mocking token based authorization. -->
    
    <!-- The (file) URL to the JSON file matching Patient resource id's to tokens used in authorization headers. -->
    <xsl:param name="tokensJsonFile"/>

    <!-- Load the JSON file as flat text in the patientTokenMap variable. It is assumed that the XSLT processor defers
         this operation unless/until it is actually needed. -->
    <xsl:variable name="patientTokenMap" select="unparsed-text($tokensJsonFile)"/>
    
    <!-- Resolve the authorization token from the JSON file. If no token was found or multiple matching tokens exist,
         an error is thrown.
         @param patientResourceId - the resource id of the Patient resource for which the token is resolved.
         @param id - an internal id to match the resolved token to a mnemonic for later use.
         @returns a list of nts:authToken XML elements with the parameters patientResourceId, token, and id. -->
    <xsl:function name="nts:resolveAuthToken" as="element(nts:authToken)?">
        <xsl:param name="patientResourceId" as="xs:string"/>
        <xsl:param name="id" as="xs:string"/>
        
        <!-- Try to find the "accessToken" key associated with "resourceId": patientId in the tokens JSON file.
             This is done in two steps: first the block with the relevant resourceId is identified, and then the
             "accessToken" value is extracted.
             Note: this could be done using the JSON parsing features of XSLT 3, but at the moment of writing this
             use case is too narrow to warrant the bump to XSLT 3. So a 'dumb' regex based method is used. -->
        <xsl:variable name="patientToken" as="xs:string*">
            <xsl:variable name="regex" select="concat('\{[^\}]*[''&quot;]resourceId[''&quot;]\s*:\s*[''&quot;]', $patientResourceId, '[''&quot;].*?\}')"/>
            <xsl:analyze-string select="$patientTokenMap" regex="{$regex}" flags="s">
                <xsl:matching-substring>
                    <xsl:analyze-string select="regex-group(0)" regex='[&apos;&quot;]accessToken[&apos;&quot;]\s*:\s*[&apos;&quot;](.*?)[&apos;&quot;]'>
                        <xsl:matching-substring>
                            <xsl:value-of select="regex-group(1)"/>
                        </xsl:matching-substring>
                    </xsl:analyze-string>
                </xsl:matching-substring>
            </xsl:analyze-string>
        </xsl:variable>

        <xsl:choose>
            <xsl:when test="count($patientToken) = 0">
                <xsl:message terminate="yes" select="concat('Couldn''t find access token for Patient resource ', $patientResourceId, ' in ', $tokensJsonFile)"/>
            </xsl:when>
            <xsl:when test="count($patientToken) &gt; 1">
                <xsl:message terminate="yes" select="concat('Multiple matches found for Patient resource ', $patientResourceId, ' in ', $tokensJsonFile)"/>
            </xsl:when>
            <xsl:otherwise>
                <nts:authToken id="{$id}" patientResourceId="{$patientResourceId}" token="{$patientToken}"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
</xsl:stylesheet>