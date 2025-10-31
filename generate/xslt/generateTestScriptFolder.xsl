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
    
    <!-- Directory containing the NTS files to be processed. -->
    <xsl:param name="inputDir" required="yes"/>

    <!-- The directory where the resulting TestScripts should be stored. -->
    <xsl:param name="outputDir" required="yes"/>
        
    <!-- The path to the base folder of fixtures, as an absolute path. -->
    <xsl:param name="referenceDir" required="yes"/>

    <!-- An NTS input file can nominate elements to only be included in specific named targets using the nts:only-in
         attribute. The "target.dir" parameter (which defaults to '#default' if no other target is specified) contains
         the full target directory defined in property 'targets.additional' (comma separated) in the build properties.
         For example: 'XIS-Server-Nictiz-intern' or 'MedicationData/Send-Nictiz-intern'. The actual target name used in
         an NTS-file is extracted from this. -->
    <xsl:param name="target.dir" select="'#default'"/>

    <!-- The FHIR version that the scripts in the folder target. Either 'stu3' or 'r4'. -->
    <xsl:param name="fhirVersion"/>
    
    <xsl:include href="generateTestScript.xsl"/>
    <xsl:include href="_ntsFolders.xsl"/>
    
    <xsl:template match="/" name="buildFilesInTargetFolder">
        <xsl:for-each select="collection(concat('file:///', $inputDir, '?select=*.xml;recurse=yes'))">
            <!-- Exclude everything in a folder that starts with '_'. Can we do this in the collection query above? -->
            <xsl:if test="not(contains(base-uri(), '/_'))">
                <!-- Get the relative directory of the input file within the base directory -->
                <xsl:variable name="nts.file.dir" select="nts:_substring-before-last(base-uri(), '/')"/>
                
                <!-- Get all properties of this folder that are to be used later -->
                <xsl:variable name="nts.file.dir.properties" as="map(*)">
                    <xsl:call-template name="ntsDirProperties">
                        <xsl:with-param name="ntsDir" select="$nts.file.dir"/>
                    </xsl:call-template>
                </xsl:variable>
                
                <!-- Get the raw file name without suffix -->
                <xsl:variable name="nts.file.basename" select="substring-before(tokenize(base-uri(), '/')[last()], '.xml')"/>
                
                <!-- Calculate the relative path to the reference dir from the NTS file -->
                <xsl:variable name="referenceBase">
                    <xsl:variable name="dirLevel" select="fn:string-length($nts.file.dir.properties('reldir')) - fn:string-length(fn:translate($nts.file.dir.properties('reldir'), '/', ''))" as="xs:integer"/>
                    <xsl:for-each select="0 to $dirLevel">
                        <xsl:if test=". gt 0">
                            <xsl:value-of select="'..'"/>
                            <xsl:if test="not(position() = last())">
                                <xsl:text>/</xsl:text>
                            </xsl:if>
                        </xsl:if>
                    </xsl:for-each>
                    <xsl:value-of select="fn:substring-after(translate($referenceDir, '\', '/'), translate($inputDir, '\', '/'))"/>
                </xsl:variable>
                
                <xsl:variable name="ntsFile" select="/f:TestScript"/>
                <xsl:variable name="ntsScenario" select="/f:TestScript/@nts:scenario"/>
                
                <xsl:variable name="testscript.path">
                    <xsl:value-of select="concat('file:///', translate($outputDir, '\', '/'))"/>
                    <xsl:choose>
                        <xsl:when test="not($target.dir = '#default')">
                            <xsl:value-of select="fn:concat('/', $target.dir, $nts.file.dir.properties('reldir.leaf'))"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="$nts.file.dir.properties('reldir')"/>
                        </xsl:otherwise>
                    </xsl:choose>
                    <xsl:value-of select="'/'"/>
                </xsl:variable>
                
                <!-- Generate output if:
                     - target is #default OR
                     - if target contains reldir (for example, target is 'XIS-Server-Nictiz-intern' while reldir is 'XIS-Server')
                     Otherwise we do nothing, because targets only have to output files affected by it. -->
                <xsl:variable name="target" select="$nts.file.dir.properties('target')"/>
                <xsl:if test="$target = '#default' or (fn:contains(fn:concat('/',$target.dir), $nts.file.dir.properties('reldir.root')) and $nts.file.dir.properties('targetLevel') = $nts.file.dir.properties('rootLevel'))">
                    <xsl:choose>
                        <xsl:when test="$ntsScenario = 'server'">
                            <!-- XIS scripts are generated in both XML and JSON flavor -->
                            <xsl:for-each select="('xml', 'json')">
                                <xsl:variable name="testscript.filename" select="fn:concat($nts.file.basename, '-', ., '.xml')"/>
                                <xsl:variable name="testScript">
                                    <xsl:apply-templates select="$ntsFile">
                                        <xsl:with-param name="target" select="$target" tunnel="yes"/>
                                        <xsl:with-param name="expectedResponseFormat" select="." tunnel="yes"/>
                                        <xsl:with-param name="referenceBase" select="$referenceBase" tunnel="yes"/>
                                    </xsl:apply-templates>
                                </xsl:variable>
                                <xsl:result-document href="{concat($testscript.path, $testscript.filename)}">
                                    <xsl:copy-of select="$testScript"/>
                                </xsl:result-document>
                            </xsl:for-each>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:variable name="testscript.filename" select="fn:concat($nts.file.basename, '.xml')"/>
                            <xsl:variable name="testScript">
                                <xsl:apply-templates select="$ntsFile">
                                    <xsl:with-param name="target" select="$target" tunnel="yes"/>
                                    <xsl:with-param name="referenceBase" select="$referenceBase" tunnel="yes"/>
                                </xsl:apply-templates>
                            </xsl:variable>
                            <xsl:result-document href="{concat($testscript.path, $testscript.filename)}">
                                <xsl:copy-of select="$testScript"/>
                            </xsl:result-document>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:if>
            </xsl:if>
        </xsl:for-each>
    </xsl:template>
    
</xsl:stylesheet>