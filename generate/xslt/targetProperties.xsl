
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
    
    <!-- Directory containing NTS-files and therefore potentially a Conformancelab src-properties file -->
    <xsl:param name="inputDir" required="yes"/>

    <!-- The directory where the resulting Conformancelab proiperties file should be stored. -->
    <xsl:param name="outputDir" required="yes"/>
        
    <!-- An NTS input file can nominate elements to only be included in specific named targets using the nts:only-in
         attribute. The "target.dir" parameter (which defaults to '#default' if no other target is specified) contains
         the full target directory defined in property 'targets.additional' (comma separated) in the build properties.
         For example: 'XIS-Server-Nictiz-intern' or 'MedicationData/Send-Nictiz-intern'. The actual target name used in
         an NTS-file is extracted from this. -->
    <xsl:param name="target.dir" select="'#default'"/>
    
    <xsl:include href="_ntsFolders.xsl"/>
    
    <xsl:template match="/" name="createPropertiesInTargetFolder">
        <xsl:variable name="ntsFolders" select="distinct-values(uri-collection(concat('file:///', $inputDir, '?select=*.xml;recurse=yes')) ! resolve-uri('.', .)[not(contains(., '/_'))]) ! string()"/>
        
        <xsl:for-each select="$ntsFolders">
            
            <!-- Get all properties of this folder that are to be used later -->
            <xsl:variable name="nts.file.dir.properties">
                <xsl:call-template name="ntsDirProperties">
                    <xsl:with-param name="ntsDir" select="."/>
                </xsl:call-template>
            </xsl:variable>
            
            <!-- Generate output if:
                 - target is #default OR
                 - if target contains reldir (for example, target is 'XIS-Server-Nictiz-intern' while reldir is 'XIS-Server')
                 Otherwise we do nothing, because targets only have to output files affected by it. -->
            <xsl:variable name="target" select="$nts.file.dir.properties('target')"/>
            <xsl:if test="$target = '#default' or (fn:contains(fn:concat('/',$target.dir), $nts.file.dir.properties('reldir.root')) and $nts.file.dir.properties('targetlevel') = $nts.file.dir.properties('rootLevel'))">
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
                
                <!-- Check if . contains a properties.json file -->
                <!-- If so AND target is #default, copy -->
                <!-- If so AND target is not #default, copy and add variant -->
                <!-- If not and target is #default, do nothing -->
                <!-- If not and target is not #default, create file and add variant -->
                <xsl:variable name="properties.path">
                    <xsl:value-of select="concat('file:///', translate($outputDir, '\', '/'))"/>
                    <xsl:choose>
                        <xsl:when test="not($target.dir = '#default')">
                            <xsl:value-of select="fn:concat('/', $target.dir, $nts.file.dir.properties('reldir.leaf'))"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="$nts.file.dir.properties('nts.reldir')"/>
                        </xsl:otherwise>
                    </xsl:choose>
                    <xsl:value-of select="'/'"/>
                </xsl:variable>
                
                <xsl:if test="not($target = '#default' and not(unparsed-text-available($srcPropertiesPath)))">
                    <xsl:result-document href="{concat($properties.path, '/properties.json')}" method="json">
                        <xsl:sequence select="$srcPropertiesModified"/>
                    </xsl:result-document>
                </xsl:if>
            </xsl:if>
        </xsl:for-each>
        
    </xsl:template>
    
</xsl:stylesheet>