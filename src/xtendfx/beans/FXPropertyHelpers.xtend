package xtendfx.beans

import javafx.beans.property.BooleanProperty
import javafx.beans.property.DoubleProperty
import javafx.beans.property.FloatProperty
import javafx.beans.property.IntegerProperty
import javafx.beans.property.ListProperty
import javafx.beans.property.LongProperty
import javafx.beans.property.ObjectProperty
import javafx.beans.property.ReadOnlyBooleanProperty
import javafx.beans.property.ReadOnlyBooleanWrapper
import javafx.beans.property.ReadOnlyDoubleProperty
import javafx.beans.property.ReadOnlyDoubleWrapper
import javafx.beans.property.ReadOnlyFloatProperty
import javafx.beans.property.ReadOnlyFloatWrapper
import javafx.beans.property.ReadOnlyIntegerProperty
import javafx.beans.property.ReadOnlyIntegerWrapper
import javafx.beans.property.ReadOnlyListProperty
import javafx.beans.property.ReadOnlyListWrapper
import javafx.beans.property.ReadOnlyLongProperty
import javafx.beans.property.ReadOnlyLongWrapper
import javafx.beans.property.ReadOnlyObjectProperty
import javafx.beans.property.ReadOnlyObjectWrapper
import javafx.beans.property.ReadOnlyStringProperty
import javafx.beans.property.ReadOnlyStringWrapper
import javafx.beans.property.SimpleBooleanProperty
import javafx.beans.property.SimpleDoubleProperty
import javafx.beans.property.SimpleFloatProperty
import javafx.beans.property.SimpleIntegerProperty
import javafx.beans.property.SimpleListProperty
import javafx.beans.property.SimpleLongProperty
import javafx.beans.property.SimpleObjectProperty
import javafx.beans.property.SimpleStringProperty
import javafx.beans.property.StringProperty
import org.eclipse.xtend.lib.macro.TransformationContext
import org.eclipse.xtend.lib.macro.declaration.MutableClassDeclaration
import org.eclipse.xtend.lib.macro.declaration.MutableFieldDeclaration
import org.eclipse.xtend.lib.macro.declaration.TypeReference
import org.eclipse.xtend.lib.macro.declaration.Visibility

class FXPropertyHelpers {
	def static createNonLazyField(boolean immutableType, MutableFieldDeclaration f, MutableClassDeclaration clazz, String propName, TypeReference propType, String fieldName, TypeReference fieldType, boolean readonly, TypeReference propTypeAPI, boolean hidden) {
		if( f.initializer === null ) {
			clazz.addField(propName) [
				type = propType
				final = true
//				initializer = ['''new «toJavaCode(propType)»(this, "«fieldName»")''']
			]	
		} else {
			clazz.addField(propName) [
				type = propType
				final = true
//				initializer = ['''new «toJavaCode(propType)»(this, "«fieldName»",_init«fieldName.toFirstUpper»())''']
			]
			
			clazz.addMethod("_init"+fieldName.toFirstUpper) [
				returnType = fieldType
				visibility = Visibility.PRIVATE
				static = true
				final = true
				body = f.initializer
			]
		}
		
		if (!hidden) {
			clazz.addMethod('get'+fieldName.toFirstUpper) [
				returnType = fieldType
				body = ['''
					return this.«propName».get();
				''']
			]
			
			if( ! readonly ) {
				clazz.addMethod('set'+fieldName.toFirstUpper) [
					addParameter(fieldName, fieldType)
					body = ['''
						this.«propName».set(«fieldName»);
					''']
				]	
			}
			
			clazz.addMethod(fieldName+'Property') [
				returnType = propTypeAPI
				body = ['''
					return «IF readonly»this.«propName».getReadOnlyProperty()«ELSE»this.«propName»«ENDIF»;
				''']
			]
		}
		
		if (! hidden) {
			f.remove
		}
	}

	def static createLazyField(boolean immutableType, MutableFieldDeclaration f, MutableClassDeclaration clazz, String propName, TypeReference propType, String fieldName, TypeReference fieldType, boolean readonly, TypeReference propTypeAPI, boolean hidden) {
		if( immutableType ) {
			if( f.initializer === null ) {
				clazz.addField("DEFAULT_" + f.simpleName.toUpperCase) [
					type = f.type 
					initializer = [f.type.defaultValue]
					final = true
					static = true
				]
			} else {
				clazz.addField("DEFAULT_" + f.simpleName.toUpperCase) [
					type = f.type 
					initializer = f.initializer
					final = true
					static = true
				]
			}
		}
		
		// add the property field
		clazz.addField(propName) [
			type = propType	
		]
		
		if (!hidden) {
			// add the getter
			clazz.addMethod('get'+fieldName.toFirstUpper) [
				returnType = fieldType
				body = ['''
					return (this.«propName» != null)? this.«propName».get() : «IF immutableType»DEFAULT_«fieldName.toUpperCase»«ELSE»this.«fieldName»«ENDIF»;
				''']
			]
			
			if( ! readonly ) {
				// add the setter
				clazz.addMethod('set'+fieldName.toFirstUpper) [
					addParameter(fieldName, fieldType)
					body = ['''
						«IF immutableType»
							this.«propName»().set(«fieldName»);
						«ELSE»
						if («propName» != null) {
							this.«propName».set(«fieldName»);
						} else {
							this.«fieldName» = «fieldName»;
						}
						«ENDIF»
					''']
				]					
			}
			
			// add the property accessor
			clazz.addMethod(fieldName+'Property') [
				returnType = propTypeAPI
				body = ['''
					if (this.«propName» == null) { 
						this.«propName» = new «toJavaCode(propType)»(this, "«fieldName»", «IF immutableType»DEFAULT_«fieldName.toUpperCase»«ELSE»this.«fieldName»«ENDIF»);
					}
					return «IF readonly»this.«propName».getReadOnlyProperty()«ELSE»this.«propName»«ENDIF»;
				''']
			]
		}
		
		// remove the property if it is immutable
		if( immutableType ) {
			f.remove
		}
	}
	
	def static String defaultValue(TypeReference ref) {
		switch ref.toString {
			case 'boolean' : "false"
			case 'double' : "0d"
			case 'float' : "0f"
			case 'long' : "0"
			case 'int' : "0"
			default : "null"
		}
	}
	
	def static TypeReference toPropertyType_API(TypeReference ref, boolean readonly, extension TransformationContext context) {
		if( readonly ) {
			switch typeName : ref.name {
				case 'boolean' : ReadOnlyBooleanProperty.newTypeReference
				case 'double' : ReadOnlyDoubleProperty.newTypeReference
				case 'float' : ReadOnlyFloatProperty.newTypeReference
				case 'long' : ReadOnlyLongProperty.newTypeReference
				case 'int' : ReadOnlyIntegerProperty.newTypeReference
				case 'String', case 'java.lang.String' : ReadOnlyStringProperty.newTypeReference  
				case typeName.startsWith('javafx.collections.ObservableList') :  ReadOnlyListProperty.newTypeReference(ref.actualTypeArguments.head)
				default : ReadOnlyObjectProperty.newTypeReference(ref)
			}
		} else {
			switch typeName : ref.name {
				case 'boolean' : BooleanProperty.newTypeReference
				case 'double' : DoubleProperty.newTypeReference
				case 'float' : FloatProperty.newTypeReference
				case 'long' : LongProperty.newTypeReference
				case 'int' : IntegerProperty.newTypeReference
				case 'String', case 'java.lang.String' : StringProperty.newTypeReference  
				case typeName.startsWith('javafx.collections.ObservableList') :  ListProperty.newTypeReference(ref.actualTypeArguments.head)
				default : ObjectProperty.newTypeReference(ref)
			}
		}
	}
	
	def static TypeReference toPropertyType(TypeReference ref, boolean readonly, extension TransformationContext context) {
		if( readonly ) {
			switch typeName : ref.name {
				case 'boolean' : ReadOnlyBooleanWrapper.newTypeReference
				case 'double' : ReadOnlyDoubleWrapper.newTypeReference
				case 'float' : ReadOnlyFloatWrapper.newTypeReference
				case 'long' : ReadOnlyLongWrapper.newTypeReference
				case 'int' : ReadOnlyIntegerWrapper.newTypeReference
				case 'String', case 'java.lang.String' : ReadOnlyStringWrapper.newTypeReference  
				case typeName.startsWith('javafx.collections.ObservableList') :  ReadOnlyListWrapper.newTypeReference(ref.actualTypeArguments.head)
				default : ReadOnlyObjectWrapper.newTypeReference(ref)
			}
		} else {
			switch typeName : ref.name {
				case 'boolean' : SimpleBooleanProperty.newTypeReference
				case 'double' : SimpleDoubleProperty.newTypeReference
				case 'float' : SimpleFloatProperty.newTypeReference
				case 'long' : SimpleLongProperty.newTypeReference
				case 'int' : SimpleIntegerProperty.newTypeReference
				case 'String', case 'java.lang.String' : SimpleStringProperty.newTypeReference  
				case typeName.startsWith('javafx.collections.ObservableList') :  SimpleListProperty.newTypeReference(ref.actualTypeArguments.head)
				default : SimpleObjectProperty.newTypeReference(ref)
			}
		}
	}
	
	def static removeSuffix(String string, String suffix) {
		if (string.endsWith(suffix)) {
			return string.substring(0, string.length - suffix.length)
		}
		
		return string
	}
}