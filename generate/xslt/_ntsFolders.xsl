<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0"
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
    
    <!-- This file contains all the templates needed to determine NTS folders and (parts of) their names -->
    
    <xsl:template name="ntsDirProperties" as="map(*)">
        <xsl:param name="ntsDir" required="true"/>
        <!-- reldir - Get the relative directory of the input file within the base directory, for example 'PHR-Client/' -->
        <xsl:variable name="nts.reldir" select="fn:substring-after($ntsDir, translate($inputDir, '\', '/'))"/>
        
        <!-- Now extract the 'root' dir of the relative path, where additional targets may be defined, and any
             subpaths following it. The 'root' is the largest combination of dir and subdirs that are defined
             in targets.additional -->
        <xsl:variable name="nts.reldir.root">
            <xsl:for-each select="fn:tokenize($nts.reldir, '/')">
                <!-- Get relative path up to and including subdir.-->
                <xsl:variable name="root.candidate">
                    <xsl:analyze-string select="$nts.reldir" regex="(/.*/{.})">
                        <xsl:matching-substring>
                            <xsl:value-of select="fn:regex-group(1)"/>
                        </xsl:matching-substring>
                    </xsl:analyze-string>
                </xsl:variable>
                <xsl:if test="not(. = '') and fn:contains(fn:concat('/',$target.dir), $root.candidate)">
                    <xsl:value-of select="concat('/',.)"/>
                </xsl:if>
            </xsl:for-each>
        </xsl:variable>
        
        <xsl:variable name="nts.reldir.leaf" select="fn:substring-after($nts.reldir, $nts.reldir.root)"/>
        
        <xsl:variable name="target">
            <xsl:choose>
                <xsl:when test="$target.dir = '#default'">
                    <xsl:value-of select="$target.dir"/>
                </xsl:when>
                <xsl:otherwise>
                    <!-- Extract the actual target name used in @nts:only-in from 'target.dir'.
                         For example: 'XIS-Server-Nictiz-intern' to 'Nictiz-intern' or 
                         'MedicationData/Send-Nictiz-intern' to 'Nictiz-intern' -->
                    <xsl:value-of select="fn:substring-after(fn:concat('/', $target.dir), fn:concat($nts.reldir.root, '-'))"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:variable name="targetLevel" select="fn:string-length($target.dir) - fn:string-length(fn:translate($target.dir, '/', '')) + 1"/>
        <xsl:variable name="rootLevel" select="fn:string-length($nts.reldir.root) - fn:string-length(fn:translate($nts.reldir.root, '/', ''))"/>
        
        <xsl:sequence select="map{
                'reldir': $nts.reldir,
                'reldir.root': $nts.reldir.root,
                'reldir.leaf': $nts.reldir.leaf,
                'target': $target,
                'targetLevel': $targetLevel,
                'rootLevel': $rootLevel
              }"/>
    </xsl:template>
    
</xsl:stylesheet>