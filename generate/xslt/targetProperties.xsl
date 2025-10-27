
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
    
    <!-- Directory potentially containing a Conformancelab properties file -->
    <xsl:param name="inputDir" required="yes"/>

    <!-- The directory where the resulting Conformancelab proiperties file should be stored. -->
    <xsl:param name="outputDir" required="yes"/>
        
    <!-- An NTS input file can nominate elements to only be included in specific named targets using the nts:only-in
         attribute. The "target.dir" parameter (which defaults to '#default' if no other target is specified) contains
         the full target directory defined in property 'targets.additional' (comma separated) in the build properties.
         For example: 'XIS-Server-Nictiz-intern' or 'MedicationData/Send-Nictiz-intern'. The actual target name used in
         an NTS-file is extracted from this. -->
    <xsl:param name="target.dir" select="'#default'"/>
    
    <xsl:template match="/" name="createPropertiesInTargetFolder">
        <xsl:variable name="ntsFolders" select="distinct-values(uri-collection(concat('file:///', $inputDir, '?select=*.xml;recurse=yes')) ! resolve-uri('.', .)[not(contains(., '/_'))]) ! string()"/>
        
        <xsl:for-each select="$ntsFolders">
            
            <!-- START DUPLICATION FROM generateTestScriptFolder -->
            <xsl:variable name="nts.reldir" select="fn:substring-after(., translate($inputDir, '\', '/'))"/>
            
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
            
            <xsl:variable name="properties.path">
                <xsl:value-of select="concat('file:///', translate($outputDir, '\', '/'))"/>
                <xsl:choose>
                    <xsl:when test="not($target.dir = '#default')">
                        <xsl:value-of select="fn:concat('/', $target.dir, $nts.reldir.leaf)"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="$nts.reldir"/>
                    </xsl:otherwise>
                </xsl:choose>
                <xsl:value-of select="'/'"/>
            </xsl:variable>
            
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
            
            <!-- Generate output if:
                 - target is #default OR
                 - if target contains reldir (for example, target is 'XIS-Server-Nictiz-intern' while reldir is 'XIS-Server')
                 Otherwise we do nothing, because targets only have to output files affected by it. -->
            <xsl:variable name="targetLevel" select="fn:string-length($target.dir) - fn:string-length(fn:translate($target.dir, '/', '')) + 1"/>
            <xsl:variable name="rootLevel" select="fn:string-length($nts.reldir.root) - fn:string-length(fn:translate($nts.reldir.root, '/', ''))"/>
            
            <xsl:if test="$target = '#default' or (fn:contains(fn:concat('/',$target.dir), $nts.reldir.root) and $targetLevel = $rootLevel)">
                <!-- END DUPLICATION FROM generateTestScriptFolder -->
                
                <xsl:variable name="srcPropertiesPath" select="concat(., 'src-properties.json')"/>
                <xsl:variable name="srcProperties" select="if (unparsed-text-available($srcPropertiesPath)) then json-doc($srcPropertiesPath) else ()"/>
                
                <xsl:variable name="variantMap"
                    select="map{'name': $target}"/>
                
                <xsl:variable name="srcPropertiesModified" as="map(*)"
                    select="
                        let $base := ($srcProperties, map{})[1]
                        return
                            if ($target eq '#default')
                            then $base
                            else if (map:contains($base, 'variant'))
                                then $base
                                else map:put($base, 'variant', $variantMap)
                    "/>
                
                <xsl:if test="not($target = '#default' and not(unparsed-text-available($srcPropertiesPath)))">
                    <xsl:result-document href="{concat($properties.path, '/properties.json')}" method="json">
                        <xsl:sequence select="$srcPropertiesModified"/>
                    </xsl:result-document>
                </xsl:if>
                
                <!-- Check if . contains a properties.json file -->
                <!-- If so AND target is #default, copy -->
                <!-- If so AND target is not #default, copy and add variant -->
                <!-- If not and target is #default, do nothing -->
                <!-- If not and target is not #default, create file and add variant -->
            </xsl:if>
        </xsl:for-each>
        
    </xsl:template>
    
</xsl:stylesheet>