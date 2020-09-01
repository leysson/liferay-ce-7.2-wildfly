##
## Docker image: Liferay 7.2.0-GA1 CE -> WildFly 11(JBoss)
##
## Build: docker build -t liferay-ce-wildfly .
## Run: docker run -it -p 8080:8080 liferay-ce-wildfly
##
FROM jboss/base-jdk:8 

# ENVIRONMENT
ENV WILDFLY_VERSION		"11.0.0.Final"
ENV WILDFLY_SHA1		"0e89fe0860a87bfd6b09379ee38d743642edfcfb"
ENV LIFERAY_VERSION		"7.2.0 GA1"
ENV LIFERAY_VERSION_FULL	"7.2.0-ga1-20190531153709761"
ENV LIFERAY_WAR_SHA1		"b411c964f2ec07c3044b6b11b13fd051159f8ba5"
ENV LIFERAY_OSGI_SHA1		"ddf46a45ff9c0b99c904af6233fb95e93e6dd783"
ENV LIFERAY_DEPS_SHA1		"099841a51b67524645a41b73901ad147ce4968e9"

# PATHS
ENV DOWNLOAD			/tmp/download/
ENV LIFERAY_HOME		/opt/app/liferay/
ENV WILDFLY_HOME		/opt/app/liferay/wildfly
ENV WILDFLY_STANDALONE_CFG 	/opt/app/liferay/wildfly/standalone/configuration/standalone.xml

# DOWNLOAD packages
RUN mkdir $DOWNLOAD \
    && cd $DOWNLOAD
RUN curl -O "https://download.jboss.org/wildfly/$WILDFLY_VERSION/wildfly-$WILDFLY_VERSION.tar.gz"
RUN curl -L -O "http://downloads.sourceforge.net/project/lportal/Liferay Portal/$LIFERAY_VERSION/liferay-ce-portal-$LIFERAY_VERSION_FULL.war"
RUN curl -L -O "http://downloads.sourceforge.net/project/lportal/Liferay Portal/$LIFERAY_VERSION/liferay-ce-portal-osgi-$LIFERAY_VERSION_FULL.zip"
RUN curl -L -O "http://downloads.sourceforge.net/project/lportal/Liferay Portal/$LIFERAY_VERSION/liferay-ce-portal-dependencies-$LIFERAY_VERSION_FULL.zip"
RUN mv *.* $DOWNLOAD

## INSTALLATION: JBOSS WildFly
USER root
COPY files /tmp/files

RUN mkdir -p $LIFERAY_HOME \
    && cd $LIFERAY_HOME \
    && sha1sum $DOWNLOAD/wildfly-$WILDFLY_VERSION.tar.gz | grep $WILDFLY_SHA1 \
    && tar xf $DOWNLOAD/wildfly-$WILDFLY_VERSION.tar.gz \
    && ln -s $LIFERAY_HOME/wildfly-$WILDFLY_VERSION wildfly 

## LIFERAY DXP
RUN mkdir $WILDFLY_HOME/standalone/deployments/ROOT.war \
    && cd $WILDFLY_HOME/standalone/deployments/ROOT.war \
    && sha1sum $DOWNLOAD/liferay-ce-portal-$LIFERAY_VERSION_FULL.war | grep $LIFERAY_WAR_SHA1 \
    && unzip $DOWNLOAD/liferay-ce-portal-$LIFERAY_VERSION_FULL.war > /dev/null \
    && touch $WILDFLY_HOME/standalone/deployments/ROOT.war.dodeploy
RUN cd $LIFERAY_HOME \
    && sha1sum $DOWNLOAD/liferay-ce-portal-osgi-$LIFERAY_VERSION_FULL.zip | grep $LIFERAY_OSGI_SHA1 \
    && unzip $DOWNLOAD/liferay-ce-portal-osgi-$LIFERAY_VERSION_FULL.zip > /dev/null \
    && find -name "liferay-ce-portal-osgi*" -exec ln -s {} osgi \;
RUN mkdir -p $WILDFLY_HOME/modules/com/liferay/portal/ \
    && cd $WILDFLY_HOME/modules/com/liferay/portal/ \
    && sha1sum $DOWNLOAD/liferay-ce-portal-dependencies-$LIFERAY_VERSION_FULL.zip | grep $LIFERAY_DEPS_SHA1 \
    && unzip $DOWNLOAD/liferay-ce-portal-dependencies-$LIFERAY_VERSION_FULL.zip > /dev/null \
    && mv liferay-ce-portal-dependencies-* main \
    && cp /tmp/files/module.xml main/

## CONFIGURATION
RUN sed -i -e '/<paths/r /tmp/files/standalone-systemmodules.xml' $LIFERAY_HOME/wildfly/modules/system/layers/base/sun/jdk/main/module.xml
RUN sed -i '/org.jboss.as.weld/d' $WILDFLY_STANDALONE_CFG \
    && sed -i -e '/\/extensions/r /tmp/files/standalone-systemproperties.xml' $WILDFLY_STANDALONE_CFG \
    && sed -i 's/<deployment-scanner/<deployment-scanner deployment-timeout="360"/g' $WILDFLY_STANDALONE_CFG \
    && sed -i -e '/<security-domains/r /tmp/files/standalone-securitydomain.xml' $WILDFLY_STANDALONE_CFG \
    && sed -i '/welcome-content/d' $WILDFLY_STANDALONE_CFG \
    && sed -i '/urn:jboss:domain:weld/d' $WILDFLY_STANDALONE_CFG
RUN cat /tmp/files/standalone.conf >> $WILDFLY_HOME/bin/standalone.conf

## USER PERMISSIONS
RUN chown -R jboss.users $LIFERAY_HOME

## CLEANUP
RUN rm -rf $HOME/files \
    && rm -rf $DOWNLOAD

# Expose the ports we're interested in EXPOSE 8080
# Set the default command to run on boot
# This will boot WildFly in the standalone mode and bind to all interface
USER jboss
CMD $WILDFLY_HOME/bin/standalone.sh -b 0.0.0.0
