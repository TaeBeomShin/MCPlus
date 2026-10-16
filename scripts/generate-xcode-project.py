#!/usr/bin/env python3
"""Generate a small native Xcode application project; no third-party generator required."""
from pathlib import Path
import hashlib, json
root=Path(__file__).resolve().parent.parent
objects={}
def ident(key): return hashlib.sha1(key.encode()).hexdigest()[:24].upper()
def add(key,isa,**fields):
    key=ident(key);objects[key]={'isa':isa,**fields};return key
def ref(key): return ident(key)
def file(path,kind): return add('file:'+path,'PBXFileReference',lastKnownFileType=kind,path=path,sourceTree='SOURCE_ROOT')
sources=[file(str(p.relative_to(root)),'sourcecode.swift') for p in sorted((root/'Sources/MCPlus').glob('*.swift'))]
resources=[file('Resources/'+name,kind) for name,kind in [('MCPlus.icns','image.icns'),('PrivacyInfo.xcprivacy','text.xml'),('Sparkle-LICENSE.txt','text')]]
framework=file('.build/vendor/Sparkle-2.10.0/Sparkle.framework','wrapper.framework')
config=file('Config/Base.xcconfig','text.xcconfig')
product=add('product','PBXFileReference',explicitFileType='wrapper.application',includeInIndex=0,path='MCPlus.app',sourceTree='BUILT_PRODUCTS_DIR')
srcphase=add('sourcesphase','PBXSourcesBuildPhase',buildActionMask=2147483647,files=[add('build:'+x,'PBXBuildFile',fileRef=x) for x in sources],runOnlyForDeploymentPostprocessing=0)
resphase=add('resourcesphase','PBXResourcesBuildPhase',buildActionMask=2147483647,files=[add('build:'+x,'PBXBuildFile',fileRef=x) for x in resources],runOnlyForDeploymentPostprocessing=0)
link=add('frameworkphase','PBXFrameworksBuildPhase',buildActionMask=2147483647,files=[add('linkframework','PBXBuildFile',fileRef=framework)],runOnlyForDeploymentPostprocessing=0)
embed=add('embedphase','PBXCopyFilesBuildPhase',buildActionMask=2147483647,dstPath='',dstSubfolderSpec=10,files=[add('embedframework','PBXBuildFile',fileRef=framework,settings={'ATTRIBUTES':['CodeSignOnCopy','RemoveHeadersOnCopy']})],name='Embed Frameworks',runOnlyForDeploymentPostprocessing=0)
products=add('products','PBXGroup',children=[product],name='Products',sourceTree='<group>')
main=add('main','PBXGroup',children=sources+resources+[framework,config,products],sourceTree='<group>')
def configs(prefix,target):
    configs=[]
    for name in ['Debug','Release']:
        settings={'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if name=='Debug' else '-O','DEBUG_INFORMATION_FORMAT':'dwarf' if name=='Debug' else 'dwarf-with-dsym'}
        if target: settings.update({'SDKROOT':'macosx','SUPPORTED_PLATFORMS':'macosx','SKIP_INSTALL':'NO','SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG' if name=='Debug' else ''})
        configs.append(add(prefix+name,'XCBuildConfiguration',baseConfigurationReference=config,buildSettings=settings,name=name))
    return add(prefix+'configs','XCConfigurationList',buildConfigurations=configs,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
target=add('target','PBXNativeTarget',buildConfigurationList=configs('target',True),buildPhases=[srcphase,link,resphase,embed],buildRules=[],dependencies=[],name='MCPlus',productName='MCPlus',productReference=product,productType='com.apple.product-type.application')
project=add('project','PBXProject',attributes={'LastUpgradeCheck':'1600'},buildConfigurationList=configs('project',False),compatibilityVersion='Xcode 14.0',developmentRegion='en',hasScannedForEncodings=0,knownRegions=['en','ko','Base'],mainGroup=main,productRefGroup=products,projectDirPath='',projectRoot='',targets=[target])
def encode(x,level=0):
    if isinstance(x,dict): return '{\n'+''.join('\t'*(level+1)+json.dumps(k)+ ' = '+encode(v,level+1)+';\n' for k,v in x.items())+'\t'*level+'}'
    if isinstance(x,list): return '( '+', '.join(encode(v,level) for v in x)+' )'
    if isinstance(x,int): return str(x)
    return json.dumps(x)
path=root/'MCPlus.xcodeproj';path.mkdir(exist_ok=True)
(path/'project.pbxproj').write_text('// !$*UTF8*$!\n'+encode({'archiveVersion':1,'classes':{},'objectVersion':56,'objects':objects,'rootObject':project})+'\n')
schemes=path/'xcshareddata/xcschemes';schemes.mkdir(parents=True,exist_ok=True)
blueprint=f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="MCPlus.app" BlueprintName="MCPlus" ReferencedContainer="container:MCPlus.xcodeproj"/>'
(schemes/'MCPlus.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{blueprint}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug"/>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{blueprint}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release"><BuildableProductRunnable runnableDebuggingMode="0">{blueprint}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print(path)
