/*
 * Copyright (C) 2025 piko <https://github.com/crimera/piko>
 *
 * See the included NOTICE file for GPLv3 §7(b) terms that apply to this code.
 *
 * Fixed by Chrispsz — setText compatibility with Instagram v430+
 * Original code called igdsButton.setText(String) directly, but IgdsButton
 * doesn't declare setText(String). It extends AppCompatButton → TextView,
 * which only has setText(CharSequence). Direct call resolves to the wrong
 * method at compile time and throws NoSuchMethodError at runtime.
 */


package app.morphe.extension.instagram.entity;

import android.widget.FrameLayout;
import android.widget.TextView;
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

    public InstagramButton(Context context) {
        super(context);
        this.igdsButton = new IgdsButton(context);
    }

    public IgdsButton getIgdsButton(){
        return this.igdsButton;
    }

    /**
     * Set text on IgdsButton safely.
     *
     * IgdsButton extends AppCompatButton → TextView, so setText(CharSequence)
     * is inherited. However, if the stub JAR declares setText(String), the
     * compiler will resolve to that — and it won't exist at runtime.
     *
     * Fix: cast to TextView to ensure we call setText(CharSequence).
     * Fallback: reflection if IgdsButton hierarchy changed.
     */
    public void setText(String text) {
        try {
            // Primary: IgdsButton extends AppCompatButton → TextView
            // Cast to TextView to call setText(CharSequence) directly.
            ((TextView) this.igdsButton).setText(text);
        } catch (Throwable t) {
            // Catch Throwable because NoSuchMethodError extends Error, not Exception
            Logger.printException(() -> "InstagramButton setText via TextView cast failed, trying reflection", t);
            try {
                // Fallback: find setText(CharSequence) via reflection on IgdsButton
                Method m = IgdsButton.class.getMethod("setText", CharSequence.class);
                m.invoke(this.igdsButton, (CharSequence) text);
            } catch (Throwable t2) {
                Logger.printException(() -> "InstagramButton setText via reflection also failed", t2);
                // Last resort: search all methods named setText
                try {
                    for (Method m : IgdsButton.class.getMethods()) {
                        if (m.getName().equals("setText") && m.getParameterCount() == 1) {
                            m.invoke(this.igdsButton, text);
                            return;
                        }
                    }
                    Logger.printException(() -> "InstagramButton: no setText method found at all", null);
                } catch (Throwable t3) {
                    Logger.printException(() -> "InstagramButton setText exhaustive fallback failed", t3);
                }
            }
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
