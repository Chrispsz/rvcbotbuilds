/*
 * Copyright (C) 2025 piko <https://github.com/crimera/piko>
 *
 * See the included NOTICE file for GPLv3 §7(b) terms that apply to this code.
 *
 * Fixed by Chrispsz — setText compatibility with Instagram v430+
 * Original code called igdsButton.setText(String) directly, but IgdsButton
 * doesn't declare setText(String) in the stub JAR. At compile time, the
 * stub resolves to setText(String) which doesn't exist at runtime.
 * At runtime, IgdsButton extends AppCompatButton → TextView which has
 * setText(CharSequence), but we can't cast because the stub doesn't
 * expose the inheritance. So we use reflection to call setText(CharSequence).
 */


package app.morphe.extension.instagram.entity;

import android.widget.FrameLayout;
import android.content.Context;
import android.view.View;
import android.view.ViewGroup;
import android.view.ViewGroup.MarginLayoutParams;
import android.animation.ObjectAnimator;

import java.lang.reflect.Method;

import app.morphe.extension.shared.Logger;
import app.morphe.extension.instagram.entity.Entity;
import app.morphe.extension.instagram.entity.InstagramButtonStyleEnum;

import com.instagram.igds.components.button.IgdsButton;

public class InstagramButton extends FrameLayout {
    private IgdsButton igdsButton;
    private static Method setTextMethod = null;
    private static boolean setTextMethodSearched = false;

    public InstagramButton(Context context) {
        super(context);
        this.igdsButton = new IgdsButton(context);
    }

    public IgdsButton getIgdsButton(){
        return this.igdsButton;
    }

    /**
     * Find the correct setText method via reflection.
     *
     * The stub JAR declares setText(String) on IgdsButton, but that method
     * doesn't exist at runtime. The real method is setText(CharSequence)
     * inherited from TextView. We can't cast to TextView because the stub
     * doesn't expose the inheritance hierarchy.
     *
     * Strategy: Walk up the class hierarchy via reflection to find
     * setText(CharSequence) on the actual superclass.
     */
    private static Method findSetTextMethod() {
        if (setTextMethodSearched) return setTextMethod;
        setTextMethodSearched = true;

        try {
            // Try setText(CharSequence) on IgdsButton first (inherited from TextView)
            try {
                setTextMethod = IgdsButton.class.getMethod("setText", CharSequence.class);
                return setTextMethod;
            } catch (NoSuchMethodException ignored) {}

            // Walk up the superclass chain looking for setText(CharSequence)
            Class<?> clazz = IgdsButton.class.getSuperclass();
            while (clazz != null) {
                try {
                    setTextMethod = clazz.getMethod("setText", CharSequence.class);
                    return setTextMethod;
                } catch (NoSuchMethodException ignored) {}
                clazz = clazz.getSuperclass();
            }

            // Last resort: find any single-arg setText method
            for (Method m : IgdsButton.class.getMethods()) {
                if (m.getName().equals("setText") && m.getParameterCount() == 1) {
                    setTextMethod = m;
                    return setTextMethod;
                }
            }
        } catch (Exception e) {
            Logger.printException(() -> "Failed to find setText method", e);
        }
        return null;
    }

    public void setText(String text) {
        try {
            Method m = findSetTextMethod();
            if (m != null) {
                m.invoke(this.igdsButton, (CharSequence) text);
            } else {
                Logger.printException(() -> "InstagramButton: no setText method found", null);
            }
        } catch (Throwable t) {
            // Catch Throwable because Error subclasses (NoSuchMethodError, etc.)
            // are not caught by Exception
            Logger.printException(() -> "InstagramButton setText failed", t);
        }
    }

    public void setOnClickListener(Runnable action) {
        this.igdsButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                try {
                    action.run();
                } catch (Exception ex) {
                    Logger.printException(() -> "Button click failed: ", ex);
                }
            }
        });
    }

    public void setStyleObject(Object style){
        // The function call for adding the button style to the button will be injected here from patches.
    }

    public void setStyle(InstagramButtonStyleEnum style){
        try {
            String styleName = style.name;
            Entity entity = new Entity();
            Class<?> styleClass = Class.forName("X.0X3");
            Object buttonStyle = entity.getMethod(
                    styleClass,
                    "valueOf",
                    styleName
            );
            setStyleObject(buttonStyle);

        } catch (Exception ex) {
            Logger.printException(() -> "Button setStyle failed: ", ex);
        }
    }

    public void setMargins(int left, int top, int right, int bottom){
        MarginLayoutParams params = new MarginLayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
        );
        params.setMargins(left, top, right, bottom);
        this.igdsButton.setLayoutParams(params);
    }

    public void startPulseAnimation() {
        IgdsButton button = getIgdsButton();
        ObjectAnimator objectAnimatorOfFloat = ObjectAnimator.ofFloat(button, "alpha", 0.6f, 1.0f);
        objectAnimatorOfFloat.setDuration(1000L);
        objectAnimatorOfFloat.setRepeatCount(-1);
        objectAnimatorOfFloat.setRepeatMode(2);
        objectAnimatorOfFloat.start();

    }
}
