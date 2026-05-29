/*
 * Copyright (C) 2026 piko <https://github.com/crimera/piko>
 *
 * See the included NOTICE file for GPLv3 §7(b) terms that apply to this code.
 *
 * Fixed by Chrispsz — setText compatibility with Instagram v430+
 * Original code called igdsButton.setText(String) directly, but IgdsButton
 * no longer has that method signature in v430+. Now uses reflection to find
 * the correct setText method (accepts CharSequence, String, or char[]).
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
     * Instagram v430+ removed setText(String) from IgdsButton.
     * We try: setText(CharSequence) → setText(String) → any single-arg setText
     */
    private static Method findSetTextMethod() {
        if (setTextMethodSearched) return setTextMethod;
        setTextMethodSearched = true;

        try {
            // Try setText(CharSequence) first (most common in newer versions)
            try {
                setTextMethod = IgdsButton.class.getMethod("setText", CharSequence.class);
                return setTextMethod;
            } catch (NoSuchMethodException ignored) {}

            // Try setText(String) (original signature)
            try {
                setTextMethod = IgdsButton.class.getMethod("setText", String.class);
                return setTextMethod;
            } catch (NoSuchMethodException ignored) {}

            // Fallback: find any method named setText with one parameter
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
                Class<?> paramType = m.getParameterTypes()[0];
                if (paramType == CharSequence.class) {
                    m.invoke(this.igdsButton, (CharSequence) text);
                } else if (paramType == String.class) {
                    m.invoke(this.igdsButton, text);
                } else {
                    m.invoke(this.igdsButton, text);
                }
            } else {
                // Last resort: try direct call (will throw if not found, caught below)
                this.igdsButton.setText(text);
            }
        } catch (Exception e) {
            Logger.printException(() -> "InstagramButton setText failed", e);
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
