package xtendfx.beans

import java.lang.annotation.Target
import java.util.List
import org.eclipse.xtend.lib.annotations.Data
import org.eclipse.xtend.lib.macro.Active
import org.eclipse.xtend.lib.macro.TransformationContext
import org.eclipse.xtend.lib.macro.TransformationParticipant
import org.eclipse.xtend.lib.macro.declaration.MutableClassDeclaration
import org.eclipse.xtend.lib.macro.declaration.MutableFieldDeclaration
import org.eclipse.xtend.lib.macro.declaration.Type
import org.eclipse.xtend.lib.macro.declaration.TypeDeclaration

import static extension xtendfx.beans.FXPropertyHelpers.*

/** 
 * An active annotation which turns simple fields into
 * lazy JavaFX properties as described  
 * <a href="http://blog.netopyr.com/2011/05/19/creating-javafx-properties/">here</a>.
 * 
 * That is it 
 * <ul>
 *  <li> adds a field with the corresponding JavaFX property type,
 *  <li> a getter method
 *  <li> a setter method
 *  <li> and an accessor to the JavaFX property.
 * </ul>
 */
@Active(FxBeanCompilationParticipant)
@Target(TYPE)
annotation FXBindable {
	boolean constructors = true
}

@Active(FxPropertyCompilationParticipant)
@Target(FIELD)
annotation FXProperty {
	boolean lazy = false
	boolean readonly = false
	boolean immutable = false
	boolean hidden = false
}


class FxPropertyCompilationParticipant implements TransformationParticipant<MutableFieldDeclaration> {
	
	override doTransform(List<? extends MutableFieldDeclaration> fields, extension TransformationContext context) {
		val fxPropertyAnnotation = FXProperty.findTypeGlobally
		
		for (field : fields) {
			val declaringType = field.declaringType
			if (!(declaringType instanceof MutableClassDeclaration)) {
				field.addError("@FXProperty can only be used on members of classes.") 
			}
			val clazz = declaringType as MutableClassDeclaration
			val fxProperty = field.findAnnotation(fxPropertyAnnotation)
			val readonly = fxProperty.getBooleanValue("readonly")
			val lazy = fxProperty.getBooleanValue("lazy")
			val immutable = fxProperty.getBooleanValue("immutable")
			val hidden = fxProperty.getBooleanValue("hidden")
			
			val fieldName = field.simpleName
			val fieldType = field.type
			val propName = field.simpleName+'Property'
			val propType = field.type.toPropertyType(readonly,context)
			val propTypeAPI = field.type.toPropertyType_API(readonly, context)
			
			if (lazy) {
				createLazyField(immutable, field, clazz, propName, propType, fieldName, fieldType, readonly, propTypeAPI, hidden)
			} else {
				createNonLazyField(immutable, field, clazz, propName, propType, fieldName, fieldType, readonly, propTypeAPI, hidden)
			}
		}
	}
	
}

class FxBeanCompilationParticipant implements TransformationParticipant<MutableClassDeclaration> {
	
	override doTransform(List<? extends MutableClassDeclaration> classes, extension TransformationContext context) {
		val fxBindableAnnotation = FXBindable.findTypeGlobally
		val fxImmutableAnnotation = Immutable.findTypeGlobally
		val dataAnnotation = Data.findTypeGlobally
		val fxReadonlyAnnotation = Readonly.findTypeGlobally
		val fxLazyAnnotation = Lazy.findTypeGlobally
		val fxHiddenAnnotation = Hidden.findTypeGlobally
		
		for (clazz : classes) {
			val fxBindable = clazz.findAnnotation(fxBindableAnnotation)
			val constructors = fxBindable.getBooleanValue("constructors")
			
			val numInitialized = clazz.declaredFields.filter[ initializer !== null].size
			
			if (constructors) {
				if (clazz.findDeclaredConstructor(clazz.declaredFields.filter[ !hasAnnotation(fxHiddenAnnotation) ].map[ type ]) === null) {
					clazz.addConstructor[ c |
						clazz.declaredFields.forEach[
							c.addParameter(simpleName, type);
						]
						
						c.body = [
							clazz.declaredFields.filter [
								!hasAnnotation(fxHiddenAnnotation)
							].map [ f |
								'''this.«f.simpleName» = new «toJavaCode(f.type)»(«f.simpleName.removeSuffix("Property")»);'''
							].join("\n")
						]
					]
				}
				
				val constructorExists = clazz.findDeclaredConstructor(clazz.declaredFields.filter[ initializer === null ].map[type]) !== null
				if (numInitialized != clazz.declaredFields.size && numInitialized != 0 && !constructorExists) {
					clazz.addConstructor[ c |
						clazz.declaredFields.filter[
							initializer === null
						].forEach[
							c.addParameter(simpleName, type)
						]
						c.body = [
							val paramNames = c.parameters.map[simpleName + "Property"].toList
							clazz.declaredFields.map [ f |
								val name = f.simpleName.removeSuffix("Proprety")
								if (paramNames.contains(f.simpleName)) {
									'''this.«f.simpleName» = new «toJavaCode(f.type)»(«name»);'''
								} else {
									'''this.«f.simpleName» = new «toJavaCode(f.type)»(_init«name.toFirstUpper»());'''
								}
							].join("\n")
						]
					]
				}
			}
			
			val allReadonly = clazz.findAnnotation(fxReadonlyAnnotation) !== null
			val allLazy = clazz.findAnnotation(fxLazyAnnotation) !== null
			val allHidden = clazz.findAnnotation(fxHiddenAnnotation) !== null
		
			for (f : clazz.declaredFields) {
				val readonly = allReadonly || f.hasAnnotation(fxReadonlyAnnotation)
				val lazy = allLazy || f.hasAnnotation(fxLazyAnnotation)
				val immutableType = f.immutableType(fxImmutableAnnotation, dataAnnotation)
				val hidden = f.hasAnnotation(fxHiddenAnnotation)
				
				val fieldName = f.simpleName
				val fieldType = f.type
				val propName = f.simpleName+'Property'
				val propType = f.type.toPropertyType(readonly,context)
				val propTypeAPI = f.type.toPropertyType_API(readonly, context)
				
				if( lazy ) {
					FXPropertyHelpers.createLazyField(immutableType, f, clazz, propName, propType, fieldName, fieldType, readonly, propTypeAPI, hidden)
				} else {
					FXPropertyHelpers.createNonLazyField(immutableType, f, clazz, propName, propType, fieldName, fieldType, readonly, propTypeAPI, hidden)
				}
			}
		}
	}
	
	def boolean hasAnnotation(MutableFieldDeclaration field, Type readonlyAnnotation) {
		return field.findAnnotation(readonlyAnnotation) !== null
	}
	
	def boolean immutableType (MutableFieldDeclaration field, Type fxImmutableAnnotation, Type dataAnnotation) {
		/*
		 * we could be more clever here e.g. java.lang.Integer is also immutable 
		 * and maybe support custom types who are annotated with @Immutable
		 */
		switch field.type.toString {
			case 'boolean' : true
			case 'double' : true
			case 'float' : true
			case 'long' : true
			case 'String' : true  
			case 'int' : true
			case 'javafx.collections.ObservableList' :  false
			default : 
				if( field.findAnnotation(fxImmutableAnnotation) !== null ) {
					return true;
				} else if( field.type.type instanceof TypeDeclaration ) {
					val t = field.type.type as TypeDeclaration
					val rv = t.findAnnotation(fxImmutableAnnotation) !== null || t.findAnnotation(dataAnnotation) !== null;
					return rv;
				} else {
					return false;
				}
		}
	}
}
