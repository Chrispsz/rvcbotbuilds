/*
    * Copyright (C) 2026 piko <https://github.com/crimera/piko>
    *
    * This file is part of piko.
    *
    * Any modifications, derivatives, or substantial rewrites of this file
    * must retain this copyright notice and the piko attribution
    * in the source code and version control history.
    *
    * OVERLAY: Resilient InstagramDialogBox - preserves root cause exceptions
    * and adds fallback constructor lookup for Instagram 430+ compatibility.
*/


package app.morphe.extension.instagram.entity;

import android.app.Dialog;
import android.content.Context;
import android.content.DialogInterface;

import java.lang.reflect.Constructor;
import java.lang.reflect.Field;
import java.lang.reflect.Method;

import app.morphe.extension.shared.Logger;

public class InstagramDialogBox{

    private final Object igdsDialog;
    private final Class<?> igdsClass;

    public InstagramDialogBox(Context context){
        Class<?> resolvedClass = null;
        Object resolvedDialog = null;

        try {
            resolvedClass = Class.forName("className");

            // Try Context constructor first (original behavior)
            try {
                Constructor<?> ctor = resolvedClass.getConstructor(Context.class);
                resolvedDialog = ctor.newInstance(context);
            } catch (NoSuchMethodException nsme) {
                Logger.printDebug(() -> "InstagramDialogBox: no Context constructor, trying alternatives");

                // Fallback 1: Try Activity constructor
                try {
                    Constructor<?> ctor = resolvedClass.getConstructor(android.app.Activity.class);
                    resolvedDialog = ctor.newInstance(context);
                } catch (NoSuchMethodException nsme2) {
                    Logger.printDebug(() -> "InstagramDialogBox: no Activity constructor, trying alternatives");

                    // Fallback 2: Try no-arg constructor
                    try {
                        Constructor<?> ctor = resolvedClass.getConstructor();
                        resolvedDialog = ctor.newInstance();
                    } catch (NoSuchMethodException nsme3) {
                        Logger.printDebug(() -> "InstagramDialogBox: no no-arg constructor either");

                        // Fallback 3: Try any constructor that takes a Context subclass
                        Constructor<?>[] ctors = resolvedClass.getConstructors();
                        for (Constructor<?> ctor : ctors) {
                            Class<?>[] paramTypes = ctor.getParameterTypes();
                            if (paramTypes.length == 1 &&
                                paramTypes[0].isAssignableFrom(context.getClass())) {
                                resolvedDialog = ctor.newInstance(context);
                                Logger.printDebug(() -> "InstagramDialogBox: found compatible constructor: " + ctor);
                                break;
                            }
                        }
                    }
                }
            }

            if (resolvedDialog == null) {
                // All attempts failed
                Constructor<?>[] ctors = resolvedClass.getConstructors();
                throw new RuntimeException("InstagramDialogBox: no compatible constructor found in " +
                    resolvedClass.getName() + ". Available constructors: " + java.util.Arrays.toString(ctors));
            }

        } catch (Throwable t) {
            throw new RuntimeException("Constructor failed for InstagramDialogBox: " + t.getMessage(), t);
        }

        igdsClass = resolvedClass;
        igdsDialog = resolvedDialog;
    }

    public void addDialogMenuItems(
            CharSequence[] items,
            DialogInterface.OnClickListener listener
    ) {
        invoke(
                "A0T",
                new Class[]{DialogInterface.OnClickListener.class, CharSequence[].class},
                listener,
                items
        );
    }

    public Dialog getDialog() {
        return (Dialog) invoke("A02", null);
    }

    public void setCancelable(boolean value) {
        invoke("A0h", new Class[]{boolean.class}, value);
    }

    public void setCanceledOnTouchOutside(boolean value) {
        invoke("A0i", new Class[]{boolean.class}, value);
    }

    public void setMessage(CharSequence message) {
        invoke("A0g", new Class[]{CharSequence.class}, message);
    }

    public void setNegativeButton(
            String text,
            DialogInterface.OnClickListener listener
    ) {
        invoke(
                "A0R",
                new Class[]{DialogInterface.OnClickListener.class, String.class},
                listener,
                text
        );
    }

    public void setOnDismissListener(
            DialogInterface.OnDismissListener listener
    ) {
        invoke(
                "A0U",
                new Class[]{DialogInterface.OnDismissListener.class},
                listener
        );
    }

    public void setPositiveButton(
            String text,
            DialogInterface.OnClickListener listener
    ) {
        invoke(
                "A0S",
                new Class[]{DialogInterface.OnClickListener.class, String.class},
                listener,
                text
        );
    }

    public void setTitle(String title) {
        try {
            Field f = igdsClass.getDeclaredField("A04");
            f.setAccessible(true);
            f.set(igdsDialog, title);
        } catch (NoSuchFieldException nsfe) {
            // "A04" field name is stale, try to find the title field by type
            try {
                Field[] fields = igdsClass.getDeclaredFields();
                for (Field f : fields) {
                    if (f.getType() == CharSequence.class || f.getType() == String.class) {
                        f.setAccessible(true);
                        f.set(igdsDialog, title);
                        Logger.printDebug(() -> "InstagramDialogBox.setTitle: used fallback field " + f.getName());
                        return;
                    }
                }
            } catch (Exception e2) {
                throw new RuntimeException("Failed to setTitle (fallback also failed)", e2);
            }
            throw new RuntimeException("Failed to setTitle: field A04 not found and no CharSequence/String fallback", nsfe);
        } catch (Throwable t) {
            throw new RuntimeException("Failed to setTitle", t);
        }
    }

    // ---------- reflection helper ----------

    private Object invoke(String name, Class<?>[] argsTypes, Object... args) {
        try {
            Method method = argsTypes!=null ? igdsClass.getDeclaredMethod(name, argsTypes): igdsClass.getDeclaredMethod(name);
            method.setAccessible(true);
            return method.invoke(igdsDialog, args);

        } catch (NoSuchMethodException nsme) {
            throw new RuntimeException("Invoke failed (method not found): " + name + " in " + igdsClass.getName(), nsme);
        } catch (Throwable t) {
            throw new RuntimeException("Invoke failed: " + name, t);
        }
    }
}
