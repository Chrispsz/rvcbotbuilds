/*
 * Copyright (C) 2026 piko <https://github.com/crimera/piko>
 *
 * See the included NOTICE file for GPLv3 §7(b) terms that apply to this code.
 *
 * OVERLAY: Resilient MediaData - hardcoded obfuscated method names (A06, A0F)
 * are stale in Instagram 430+. These methods now gracefully return null on
 * failure instead of crashing, allowing the download dialog to still open
 * (just without audio download option).
 */


package app.morphe.extension.instagram.entity;

import java.util.List;
import java.util.Arrays;
import java.util.HashSet;

import android.content.Context;

import app.morphe.extension.shared.Utils;
import app.morphe.extension.shared.Logger;


public class MediaData extends Entity {
    private final Object obj;

    public MediaData(Object obj) {
        super(obj);
        this.obj = obj;
    }

    private Class<?> getHelperClass() throws Exception {
        return Class.forName("className");
    }

    private Object getExtendedData() throws Exception {
        return super.getField("fieldName");
    }

    public String getMediaPkId() throws Exception {
        return (String) super.getMethod("methodName");
    }

    // Sometimes I want to forcefully generate file name as an image while saving the video/media as an image file.
    public String getDownloadFilename(boolean forceAsImage) throws Exception {
        String extension = this.isVideo() ? ".mp4" : ".jpg";
        extension = forceAsImage ? ".jpg" : extension;
        String mediaPkId = this.getMediaPkId();
        return mediaPkId + extension;

    }

    public UserData getUserData() throws Exception {
        Object userData = super.getMethod(this.getExtendedData(), "methodName");
        return new UserData(userData);
    }

    public HashSet getMentionSet() throws Exception {
        Class<?> helperClass = this.getHelperClass();
        Object result = super.getMethod(helperClass, "methodName", this.obj);
        if (result != null) {
            return new HashSet<>((List) result);
        }
        return null;
    }

    public List<Object> getMediaList() throws Exception {
        List mediaList = (List) super.getMethod(this.getExtendedData(), "methodName");
        if (mediaList != null) {
            return mediaList;
        }
        return Arrays.asList(this.obj);
    }

    public int getCarouselSize() throws Exception {
        return this.getMediaList().size();
    }

    public MediaData getMediaAt(int position) throws Exception {
        List<Object> mediaList = this.getMediaList();
        if (mediaList.isEmpty()) return new MediaData(this.obj);

        int safePosition = Math.max(0, Math.min(position, mediaList.size() - 1));
        return new MediaData(mediaList.get(safePosition));
    }

    public String getPhotoLink() throws Exception {
        Context context = Utils.getContext();

        Class<?> helperClass = this.getHelperClass();
        Object photoLink = super.getMethod(helperClass, "methodName", new Class[]{Context.class, this.obj.getClass()}, context, this.obj);
        return photoLink != null ? (String) photoLink : null;
    }

    public String getVideoLink() throws Exception {
        Class<?> helperClass = this.getHelperClass();
        Object result = super.getMethod(helperClass, "methodName", this.obj);
        return result != null ? (String) result : null;
    }

    public boolean isVideo() throws Exception {
        return (boolean) super.getMethod(this.obj, "methodName");
    }

    public String getMediaLink() throws Exception {
        return this.isVideo() ? this.getVideoLink() : this.getPhotoLink();
    }

    /**
     * Get original sound data from media.
     * The obfuscated method name "A06" may be stale in newer Instagram versions.
     * Falls back to scanning the helper class for a matching method by signature.
     */
    private OriginalSoundDataIntf getOriginalSoundDataIntf() {
        try {
            Class<?> helperClass = this.getHelperClass();
            // Try the patched/hardcoded method name first
            Object result = super.getMethod(helperClass, "A06", this.obj);
            if (result != null) {
                return new OriginalSoundDataIntf(result);
            }
        } catch (NoSuchMethodException e) {
            // "A06" is stale, try to find method by signature
            try {
                Object result = findMethodBySignature("A06", this.obj);
                if (result != null) {
                    return new OriginalSoundDataIntf(result);
                }
            } catch (Exception e2) {
                Logger.printException(() -> "getOriginalSoundDataIntf: fallback also failed", e2);
            }
        } catch (Exception e) {
            Logger.printException(() -> "getOriginalSoundDataIntf failed", e);
        }
        return null;
    }

    /**
     * Get track data from media.
     * The obfuscated method name "A0F" may be stale in newer Instagram versions.
     * Falls back to scanning the helper class for a matching method by signature.
     */
    private TrackDataIntf getTrackDataIntf() {
        try {
            Class<?> helperClass = this.getHelperClass();
            // Try the patched/hardcoded method name first
            Object result = super.getMethod(helperClass, "A0F", this.obj);
            if (result != null) {
                return new TrackDataIntf(result);
            }
        } catch (NoSuchMethodException e) {
            // "A0F" is stale, try to find method by signature
            try {
                Object result = findMethodBySignature("A0F", this.obj);
                if (result != null) {
                    return new TrackDataIntf(result);
                }
            } catch (Exception e2) {
                Logger.printException(() -> "getTrackDataIntf: fallback also failed", e2);
            }
        } catch (Exception e) {
            Logger.printException(() -> "getTrackDataIntf failed", e);
        }
        return null;
    }

    public AudioMediaInterface getAudioMedia() {
        AudioMediaInterface originalSoundDataIntf = this.getOriginalSoundDataIntf();
        if (originalSoundDataIntf != null) {
            return originalSoundDataIntf;
        }

        AudioMediaInterface TrackDataIntf = this.getTrackDataIntf();
        if (TrackDataIntf != null) {
            return TrackDataIntf;
        }
        return null;
    }

    /**
     * Description text extraction.
     * "A0J" and "A0Z" ARE patched by GetDescriptionTextExtensionFingerprint,
     * so they should be correct. But wrap in try/catch for safety.
     */
    public String getDescriptionText() {
        try {
            Class<?> helperClass = this.getHelperClass();
            Object result = super.getMethod(helperClass, "A0J", this.obj);
            return result != null ? (String) super.getField(result, "A0Z") : null;
        } catch (Exception e) {
            Logger.printException(() -> "getDescriptionText failed", e);
            return null;
        }
    }

    /**
     * Fallback method scanner: when a hardcoded obfuscated method name is stale,
     * scan the helper class for static methods that take a single parameter
     * of the same type as `obj` and return a non-primitive result.
     * Tries each matching method until one returns a non-null result.
     */
    private Object findMethodBySignature(String staleName, Object param) throws Exception {
        Class<?> helperClass = this.getHelperClass();
        Class<?> paramType = param.getClass();
        java.lang.reflect.Method[] methods = helperClass.getDeclaredMethods();

        for (java.lang.reflect.Method m : methods) {
            // Looking for static methods (Kotlin extension functions compiled as static)
            // that take exactly 1 parameter matching our param type
            Class<?>[] paramTypes = m.getParameterTypes();
            if (paramTypes.length == 1 && paramTypes[0].isAssignableFrom(paramType)) {
                Class<?> returnType = m.getReturnType();
                // Skip void and primitive returns
                if (returnType == void.class || returnType.isPrimitive()) {
                    continue;
                }
                // Skip methods we know aren't audio-related (like getPhotoLink, getVideoLink, etc.)
                // by checking return type isn't String
                if (returnType == String.class) {
                    continue;
                }
                try {
                    m.setAccessible(true);
                    Object result = m.invoke(null, param);
                    if (result != null) {
                        Logger.printDebug(() -> "findMethodBySignature: found replacement for " + staleName + " -> " + m.getName());
                        return result;
                    }
                } catch (Exception ignored) {
                    // This method didn't work, try the next one
                }
            }
        }
        Logger.printDebug(() -> "findMethodBySignature: no replacement found for " + staleName);
        return null;
    }

}
