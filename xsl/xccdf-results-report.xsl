<?xml version="1.0" encoding="UTF-8" ?>
<!--
Copyright 2010 Red Hat Inc., Durham, North Carolina.
All Rights Reserved.

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA

Authors:
     Lukas Kuklinek <lkuklinek@redhat.com>
-->


<xsl:stylesheet version="1.1"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.w3.org/1999/xhtml"
	xmlns:h="http://www.w3.org/1999/xhtml"
	xmlns:cdf="http://checklists.nist.gov/xccdf/1.1"
    xmlns:fn="http://www.w3.org/2005/xpath-functions"
    xmlns:exsl="http://exslt.org/common"
    xmlns:s="http://open-scap.org/"
    xmlns:edate="http://exslt.org/dates-and-times">

<!--<xsl:include href="xccdf-common.xsl" />-->
<xsl:import href="xccdf-apply-profile.xsl" />

<!--
     TODO:
     - human-readable URNs
       - result strings (?)
       - scoring systems
       - target facts
     - xml:lang awareness
     - dereference <sub/> element
     - dereference special XCCDF links
     - include metainfo (OpenSCAP version, generation time, ...)
     - check 'hidden' attribute
-->

<xsl:output method="xml" encoding="UTF-8" indent="yes"/>

<xsl:variable name='end-times'>
  <s:times>
  <xsl:for-each select='/cdf:Benchmark/cdf:TestResult/@end-time'>
    <xsl:sort order='descending'/>
    <s:t t='{.}'/>
  </xsl:for-each>
  </s:times>
</xsl:variable>

<xsl:variable name='last-test-time' select='exsl:node-set($end-times)/s:times/s:t[1]/@t'/>

<!-- parameters -->
<xsl:param name="result-id" select='/cdf:Benchmark/cdf:TestResult[@end-time=$last-test-time][last()]/@id'/>
<xsl:param name="with-target-facts"/>
<xsl:param name="show"/>
<xsl:param name='profile' select='/cdf:Benchmark/cdf:TestResult[@id=$result-id][1]/cdf:profile/@idref'/>

<xsl:variable name='benchmark'>
  <xsl:apply-templates select='/cdf:Benchmark' mode='profile'>
    <xsl:with-param name='p' select='/cdf:Benchmark/cdf:Profile[@id=$profile]'/>
  </xsl:apply-templates>
</xsl:variable>

<xsl:variable name='root' select='exsl:node-set($benchmark)/cdf:Benchmark'/>

<xsl:variable name='result' select='$root/cdf:TestResult[@id=$result-id][1]'/>
<!--<xsl:variable name='result' select='/cdf:Benchmark/cdf:TestResult[@id=$result-id][1]'/>-->

<xsl:variable name='toshow'>
  <xsl:choose>
    <xsl:when test='substring($show, 1, 1) = "="'>,<xsl:value-of select='substring($show, 2)'/>,</xsl:when>
    <xsl:otherwise>,pass,fixed,notchecked,informational,unknown,error,fail,<xsl:value-of select='$show'/>,</xsl:otherwise>
  </xsl:choose>
</xsl:variable>

<!-- keys -->
<xsl:key name="items" match="cdf:Group|cdf:Rule|cdf:Value" use="@id"/>
<xsl:key name="profiles" match="cdf:Profile" use="@id"/>


<!-- top-level template -->
<xsl:template match="/cdf:Benchmark">
  <xsl:call-template name='warn-unresolved'/>
  <xsl:choose>
    <xsl:when test='count(cdf:TestResult) = 0'>
      <xsl:message terminate='yes'>This benchmark does not contain any test results.</xsl:message>
    </xsl:when>
    <xsl:when test='$result-id and $result'>
      <xsl:message>TestResult ID: <xsl:value-of select='$result-id'/></xsl:message>
      <xsl:message>Profile: <xsl:value-of select='$profile'/></xsl:message>
      <xsl:apply-templates select='$result' mode='result' />
    </xsl:when>
    <xsl:when test='$result-id'>
      <xsl:message terminate='yes'>No such result exists.</xsl:message>
    </xsl:when>
    <xsl:otherwise>
      <xsl:message terminate='yes'>No result ID specified.</xsl:message>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="/cdf:TestResult">
  <xsl:apply-templates select='.' mode='result' />
</xsl:template>


<!-- index mode -->

<xsl:template match="cdf:Benchmark" mode='index'>
  <xsl:choose>
  <xsl:when test='cdf:TestResult'>
    <p>List of executed tests (<xsl:value-of select='count(cdf:TestResult)'/>):</p>
    <ol>
        <xsl:apply-templates select='cdf:TestResult' mode='index' />
    </ol>
  </xsl:when>
  <xsl:otherwise>
    <p>Benchmark file does not contain any tests.</p>
  </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="cdf:TestResult" mode='index'>
  <li><a href="result-{@id}.html"><xsl:value-of select='cdf:title[1]'/> (<xsl:value-of select='@id'/>)</a>
  <xsl:value-of select='concat(" ", @end-time)'/></li>
</xsl:template>

<!-- result mode -->

<xsl:template match='cdf:TestResult' mode='result'>
  <xsl:variable name='results' select='cdf:rule-result[contains($toshow, concat(",",cdf:result,",")) and not(contains($toshow, concat(",-",cdf:result,",")))]'/>
  <xsl:call-template name='skelet'>
    <xsl:with-param name='file' select="concat('result-', @id, '.html')" />
    <xsl:with-param name='title' select='string(cdf:title[1])'/>
    <xsl:with-param name='footer'><a href="http://scap.nist.gov/specifications/xccdf/">XCCDF</a> benchmark result report.</xsl:with-param>
    <xsl:with-param name='content'>

      <h2 id='summary'>Summary</h2>

      <p>During <em><xsl:value-of select='cdf:title[1]'/></em> (ID <xsl:value-of select='@id'/>) processing
         <xsl:if test='cdf:benchmark'> using the <em><xsl:value-of select='cdf:benchmark/@href'/></em> benchmark </xsl:if>
         <xsl:if test='cdf:identity'> triggered by <em><xsl:value-of select='cdf:identity'/></em></xsl:if>
         which <xsl:if test='@start-time'> started <xsl:apply-templates mode='date' select='@start-time'/> and </xsl:if>
         ended <xsl:apply-templates mode='date' select='@end-time'/>,
         <xsl:value-of select='count(cdf:rule-result)'/> rule results were recorded.
      </p>

      <xsl:apply-templates select='@id|cdf:benchmark|cdf:version|@start-time|@end-time|cdf:profile|cdf:identity' mode='result' />

      <p>Target: <strong><xsl:value-of select='cdf:target[1]'/></strong><xsl:for-each select='cdf:target[position() &gt; 1]'>,
                                       <strong><xsl:value-of select='.'/></strong></xsl:for-each></p>

       <p>Rule results: <strong><xsl:value-of select='count(cdf:rule-result)'/></strong></p>
       <table class='raw'>
         <tr><td>pass</td><td><xsl:value-of select='count(cdf:rule-result[cdf:result="pass"])'/></td></tr>
         <tr><td>fixed</td><td><xsl:value-of select='count(cdf:rule-result[cdf:result="fixed"])'/></td></tr>
         <tr><td>fail</td><td><xsl:value-of select='count(cdf:rule-result[cdf:result="fail"])'/></td></tr>
         <tr><td>error</td><td><xsl:value-of select='count(cdf:rule-result[cdf:result="error"])'/></td></tr>
         <tr><td>not selected</td><td><xsl:value-of select='count(cdf:rule-result[cdf:result="notselected"])'/></td></tr>
         <tr><td>not checked</td><td><xsl:value-of select='count(cdf:rule-result[cdf:result="notchecked"])'/></td></tr>
         <tr><td>not applicable</td><td><xsl:value-of select='count(cdf:rule-result[cdf:result="notapplicable"])'/></td></tr>
         <tr><td>informational</td><td><xsl:value-of select='count(cdf:rule-result[cdf:result="informational"])'/></td></tr>
         <tr><td>unknown</td><td><xsl:value-of select='count(cdf:rule-result[cdf:result="unknown"])'/></td></tr>
       </table>

      <h2 id='target-info'>Target information</h2>

      <xsl:call-template name='list'>
        <xsl:with-param name='nodes' select='cdf:target' />
        <xsl:with-param name='title' select='"Target"' />
      </xsl:call-template>

      <xsl:call-template name='list'>
        <xsl:with-param name='nodes' select='cdf:target-address' />
        <xsl:with-param name='title' select='"Addresses"' />
      </xsl:call-template>

    <xsl:if test="$with-target-facts">
      <xsl:apply-templates select='cdf:target-facts' mode='result' />
    </xsl:if>

      <h2 id='benchmark-info'>Benchmark execution information</h2>

      <xsl:call-template name='list'>
        <xsl:with-param name='nodes' select='cdf:remark' />
        <xsl:with-param name='title' select='"Remarks"' />
      </xsl:call-template>

      <xsl:if test='cdf:platform'>
        <h3 id='platform-list'>Platform</h3>
        <ul>
        <xsl:for-each select='cdf:platform'>
          <li><xsl:value-of select='@idref'/></li>
        </xsl:for-each>
        </ul>
      </xsl:if>

      <xsl:if test='cdf:set-value'>
        <h3 id='values'>Values</h3>
        <table>
        <tr><th>Name</th><!--<th>ID</th>--><th>Value</th></tr>
        <xsl:for-each select='cdf:set-value'>
          <tr>
            <td>
              <xsl:call-template name='ifelse'>
                <xsl:with-param name='test' select='key("items",@idref)/cdf:title' />
                <xsl:with-param name='true'><abbr title='ID: {@idref}'><xsl:value-of select='key("items",@idref)/cdf:title[1]'/></abbr></xsl:with-param>
                <xsl:with-param name='false'><xsl:value-of select='@idref'/></xsl:with-param>
              </xsl:call-template>
            </td>
            <td><xsl:value-of select='.'/></td>
          </tr>
        </xsl:for-each>
        </table>
      </xsl:if>

      <xsl:call-template name='list'>
        <xsl:with-param name='nodes' select='cdf:organization' />
        <xsl:with-param name='title' select='"Organization"' />
      </xsl:call-template>

      <h2 id='score'>Score</h2>
      <xsl:call-template name='ifelse'>
        <xsl:with-param name='test' select='cdf:score'/>
        <xsl:with-param name='true'>
          <table>
            <tr><th>system</th><th>score</th><th>max</th><th>bar</th></tr>
            <xsl:for-each select='cdf:score'>
            <xsl:variable name='max'>
              <xsl:choose>
                <xsl:when test='@maximum'><xsl:value-of select='@maximum'/></xsl:when>
                <xsl:otherwise>100</xsl:otherwise>
              </xsl:choose>
            </xsl:variable>
            <xsl:variable name='percent' select='number(.) div number($max)'/>
            <xsl:variable name='format' select="'#.00'"/>
            <tr>
              <td class='score-sys'><xsl:value-of select='@system' /></td>
              <td class='score-val'><xsl:value-of select='format-number(string(.), $format)' /></td>
              <td class='score-max'><xsl:value-of select='format-number($max, $format)' /></td>
              <td class='score-bar'><div class='score-outer'><div class='score-inner' style="width:{format-number($percent, '#.00%')}"></div></div></td>
            </tr>
            </xsl:for-each>
          </table>
        </xsl:with-param>
        <xsl:with-param name='false'><p class='unknown'>No score results.</p></xsl:with-param>
      </xsl:call-template>

      <h2 id='results-summary'>Rule results</h2>
      <xsl:call-template name='ifelse'>
        <xsl:with-param name='test' select='cdf:rule-result'/>
        <xsl:with-param name='true'>
          <table>
            <tr><th>Title</th><th>result</th><th>more</th></tr>
            <xsl:for-each select='$results'>
              <tr class='result-{string(cdf:result)}'>
                <td class='id'>
                  <xsl:choose>
                    <xsl:when test='key("items",@idref)/cdf:title'>
                      <abbr title='ID: {@idref}'><xsl:value-of select='key("items",@idref)/cdf:title[1]'/></abbr>
                    </xsl:when>
                    <xsl:otherwise>
                      <xsl:value-of select='@idref'/>
                    </xsl:otherwise>
                  </xsl:choose>
                </td>
                <td class='result'><strong><xsl:value-of select='cdf:result'/></strong></td>
                <td class='link'><a href="#ruleresult-{generate-id(.)}">view</a></td>
              </tr>
            </xsl:for-each>
          </table>
        </xsl:with-param>
        <xsl:with-param name='false'><p class='unknown'>No rule results.</p></xsl:with-param>
      </xsl:call-template>
      
      <xsl:apply-templates select='$results' mode='rr'/>


    </xsl:with-param>
  </xsl:call-template>
</xsl:template>

<xsl:template match='cdf:benchmark' mode='result'>
    <p>Used XCDF benchmark URI: <strong><xsl:value-of select='@href'/></strong></p>
</xsl:template>

<xsl:template match='@id' mode='result'>
    <p>Result ID: <strong><xsl:value-of select='.'/></strong></p>
</xsl:template>

<xsl:template match='cdf:identity' mode='result'>
    <p>Identity: <strong><xsl:value-of select='.'/></strong>
      (<xsl:if test='@authenticated!="1"'>not </xsl:if>authenticated, <xsl:if test='@privileged!="1"'>not </xsl:if>privileged)</p>
</xsl:template>

<xsl:template match='cdf:version' mode='result'>
    <p>Version: <strong><xsl:value-of select='.'/></strong><xsl:if test='@update'> [<a href="{@update}">updates</a>]</xsl:if></p>
</xsl:template>

<xsl:template match='@end-time' mode='result'>
    <p>End time: <strong><xsl:apply-templates mode='date' select='.'/></strong></p>
</xsl:template>

<xsl:template match='@start-time' mode='result'>
    <p>Start time: <strong><xsl:apply-templates mode='date' select='.'/></strong></p>
</xsl:template>

<xsl:template match='cdf:profile' mode='result'>
    <p>Profile: <strong><xsl:value-of select='@idref'/></strong></p>
</xsl:template>

<xsl:template match='cdf:target-facts' mode='result'>
  <h3>Target facts</h3>
  <table>
    <tr><th>Fact</th><th>Value</th></tr>
    <xsl:for-each select='cdf:fact'>
      <tr><td><xsl:value-of select='@name'/></td><td><xsl:value-of select='.'/></td></tr>
    </xsl:for-each>
  </table>
</xsl:template>

<xsl:template mode='result' />

<!-- rule result mode -->

<xsl:template match='cdf:rule-result' mode='rr'>
  <xsl:variable name='rid'  select='@idref'/>
  <xsl:variable name='rule' select="key('items',@idref)"/>-->
  <xsl:variable name='title'>
    <xsl:if test="key('items',@idref)/cdf:title"><xsl:value-of select="key('items',@idref)/cdf:title[1]"/></xsl:if>
    <xsl:if test="not(key('items',@idref)/cdf:title)"><xsl:value-of select='@idref'/></xsl:if>
  </xsl:variable>

    <div class='result-detail' id='ruleresult-{generate-id(.)}'>
     <h3>Result for <xsl:value-of select="$title"/></h3>
     <p class="result-{cdf:result}">Result: <strong><xsl:value-of select="cdf:result"/></strong></p>
     <p>Rule ID: <strong><xsl:value-of select="@idref"/></strong></p>
    
     <!-- time -->
     <xsl:apply-templates select='@time' mode='rr'/>
    
     <!-- version (result or rule) -->
     <xsl:apply-templates select='cdf:version' mode='result'/>
    
     <!-- severity (result or rule) -->
     <xsl:apply-templates select='@severity' mode='rr'/>
    
     <!-- rule status -->
     <xsl:apply-templates select='$rule/status[last()]' mode='rr'/>
    
     <!-- instances (n) -->
     <xsl:if test='cdf:instance'>
       <h4>Instance</h4>
       <ul><xsl:apply-templates select='cdf:instance' mode='rr'/></ul>
     </xsl:if>
    
     <!-- rule desc (rule) -->
     <xsl:if test='$rule and $rule/cdf:description'>
       <h4>Rule description</h4>
       <p><xsl:apply-templates mode='text' select='$rule/cdf:description[1]'/></p>
     </xsl:if>
    
     <!-- rationale -->
     <xsl:if test='$rule and $rule/cdf:rationale'>
       <h4>Rationale</h4>
       <p><xsl:apply-templates mode='text' select='$rule/cdf:rationale[1]'/></p>
     </xsl:if>
    
     <!-- warning -->
     <xsl:if test='$rule and $rule/cdf:warning'>
       <h4>Warning</h4>
       <p class='warning'><xsl:apply-templates mode='text' select='$rule/cdf:warning[1]'/></p>
     </xsl:if>
    
     <!-- ident (n) -->
     <xsl:if test='cdf:ident'>
       <h4>Related identifiers</h4>
       <ul>
         <xsl:for-each select='cdf:ident'>
           <li><strong><xsl:value-of select='.'/></strong> (<xsl:value-of select='@system'/>)</li>
         </xsl:for-each>
       </ul>
     </xsl:if>
    
     <!-- overrides (n) -->
     <xsl:if test='cdf:override'>
       <h4>Result overrides</h4>
       <ul><xsl:apply-templates select='cdf:override' mode='rr'/></ul>
     </xsl:if>
    
     <!-- messages (n) -->
     <xsl:call-template name='list'>
       <xsl:with-param name='nodes' select='cdf:message' />
       <xsl:with-param name='el' select='"ol"' />
       <xsl:with-param name='title' select='"Messages from the checking engine"' />
     </xsl:call-template>
    
     <!-- fixtext (rule, 0-1) -->
     <xsl:if test='$rule and $rule/cdf:fixtext'>
       <h4>Fix instructions</h4>
       <p><xsl:apply-templates mode='text' select='$rule/cdf:fixtext[1]'/></p>
     </xsl:if>
    
     <!-- fix script (result or rule, 0-1) -->
     <xsl:for-each select='(cdf:fix|$rule/cdf:fix)[last()]'>
       <h4>Fix script</h4>
       <pre class='code'><code><xsl:apply-templates mode='text' select='.'/></code></pre>
     </xsl:for-each>
    
     <!-- references -->
     <xsl:if test='$rule and $rule/cdf:reference[@href]'>
       <h4>References</h4>
       <ol><xsl:apply-templates select='$rule/cdf:reference[@href]' mode='rr'/></ol>
     </xsl:if>
    
     <p class='link'><a href='#results-summary'>results summary</a></p>
    
    </div>
</xsl:template>

<xsl:template match='@time' mode='rr'><p>Time: <strong><xsl:apply-templates mode='date' select='.'/></strong></p></xsl:template>
<xsl:template match='@severity' mode='rr'><p class="severity-{.}">Severity: <strong><xsl:value-of select='.'/></strong></p></xsl:template>
<xsl:template match='cdf:status' mode='rr'><p>Rule status: <strong><xsl:value-of select='.'/></strong></p></xsl:template>

<xsl:template match='cdf:override' mode='rr'>
  <li><p>Overridden on <xsl:apply-templates mode='date' select='@time'/>
        <xsl:if test='@authority'> by <strong><xsl:value-of select='@authority'/></strong></xsl:if>
        from <span class="result-{cdf:old-result}"><strong><xsl:value-of select='cdf:old-result'/></strong></span>
        to <span class="result-{cdf:new-result}"><strong><xsl:value-of select='cdf:new-result'/></strong></span>.</p>
      <p class='remark'><xsl:value-of select='cdf:remark'/></p></li>
</xsl:template>

<xsl:template match='cdf:instance' mode='rr'>
  <li><p><xsl:value-of select='.'/>
         <xsl:if test='@context'> [context: <xsl:value-of select='@context'/>]</xsl:if>
         <xsl:if test='@parentContext'> [parent context: <xsl:value-of select='@parentContext'/>]</xsl:if>
  </p></li>
</xsl:template>

<xsl:template match='cdf:reference' mode='rr'>
  <li><a href='{@href}'><xsl:value-of select='@href'/></a></li>
</xsl:template>

<xsl:template mode='rr' />

</xsl:stylesheet>

